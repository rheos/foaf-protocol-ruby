# frozen_string_literal: true

module Api
  module V1
    class PathfindingController < ApiController
      before_action :find_network!

      # POST /api/v1/networks/:address/path-info
      # Find a transfer path between two users.
      # Mirrors Trustlines relay POST /networks/:addr/path-info
      def path_info
        # BFS pathfinding through the trust graph
        path = find_path(
          from: params[:from],
          to: params[:to],
          value: BigDecimal(params[:value].to_s),
          max_hops: (params[:maxHops] || @network.max_hops).to_i
        )

        if path
          render json: {
            path: path,
            value: params[:value].to_i,
            fees: "0",
            feePayer: params[:feePayer] || "sender"
          }
        else
          render json: { error: "No path found" }, status: :not_found
        end
      end

      # POST /api/v1/networks/:address/max-capacity-path-info
      def max_capacity_path_info
        path = find_path(
          from: params[:from],
          to: params[:to],
          value: BigDecimal("0"),  # find any path first
          max_hops: (params[:maxHops] || @network.max_hops).to_i
        )

        if path
          # Calculate max capacity along the path
          capacity = calculate_path_capacity(path)
          render json: {
            capacity: capacity.to_i.to_s,
            path: path
          }
        else
          render json: { capacity: "0", path: [] }
        end
      end

      # POST /api/v1/networks/:address/close-trustline-path-info
      def close_trustline_path_info
        # Find a triangular path to zero out the balance
        render json: { error: "Not yet implemented" }, status: :not_implemented
      end

      private

      def find_network!
        @network = CurrencyNetwork.find_by!(address: params[:address])
      end

      # BFS pathfinding through the trust graph.
      # Mirrors Trustlines relay network_graph — off-ledger, pure query.
      def find_path(from:, to:, value:, max_hops:)
        return nil if from == to
        return [from, to] if direct_path_exists?(from, to, value)

        visited = Set.new([from])
        queue = [[from, [from]]]

        while queue.any?
          current, path = queue.shift
          break if path.size > max_hops + 1

          neighbors(current).each do |neighbor|
            next if visited.include?(neighbor)
            visited.add(neighbor)

            new_path = path + [neighbor]
            return new_path if neighbor == to

            queue.push([neighbor, new_path]) if new_path.size <= max_hops + 1
          end
        end

        nil
      end

      def direct_path_exists?(from, to, value)
        tl = Foaf::TrustlineRecord.in_network(@network.id).between(from, to).first
        return false unless tl
        return false if tl.is_frozen

        sender_is_a = tl.user_is_a?(from)
        balance = Foaf::Trustline::Protocol::BalanceMath.balance_for_user(
          balance: tl.balance, user_is_a: sender_is_a
        )
        received = Foaf::Trustline::Protocol::BalanceMath.creditline_received_for_user(
          creditline_a_to_b: tl.creditline_given,
          creditline_b_to_a: tl.creditline_received,
          user_is_a: sender_is_a
        )
        capacity = Foaf::Trustline::Protocol::BalanceMath.capacity(
          balance: balance, creditline_received: received
        )

        capacity >= value
      end

      def neighbors(address)
        Foaf::TrustlineRecord.in_network(@network.id)
          .for_address(address)
          .where(is_frozen: false, allow_routing: true)
          .map { |tl| tl.counterparty(address) }
      end

      def calculate_path_capacity(path)
        min_capacity = nil

        path.each_cons(2) do |sender, receiver|
          tl = Foaf::TrustlineRecord.in_network(@network.id).between(sender, receiver).first
          next unless tl

          sender_is_a = tl.user_is_a?(sender)
          balance = Foaf::Trustline::Protocol::BalanceMath.balance_for_user(
            balance: tl.balance, user_is_a: sender_is_a
          )
          received = Foaf::Trustline::Protocol::BalanceMath.creditline_received_for_user(
            creditline_a_to_b: tl.creditline_given,
            creditline_b_to_a: tl.creditline_received,
            user_is_a: sender_is_a
          )
          capacity = Foaf::Trustline::Protocol::BalanceMath.capacity(
            balance: balance, creditline_received: received
          )

          min_capacity = capacity if min_capacity.nil? || capacity < min_capacity
        end

        min_capacity || BigDecimal("0")
      end
    end
  end
end
