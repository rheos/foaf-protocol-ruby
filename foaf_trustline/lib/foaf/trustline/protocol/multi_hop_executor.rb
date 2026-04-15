# frozen_string_literal: true

module Foaf
  module Trustline
    module Protocol
      # Multi-hop transfer execution logic.
      # Mirrors CurrencyNetworkBasic._mediatedTransferSenderPays / _mediatedTransferReceiverPays.
      # No Rails, no I/O, no database.
      #
      # This module validates and computes the balance changes for a multi-hop
      # transfer. The actual persistence and locking is handled by the service layer.
      module MultiHopExecutor
        module_function

        # Compute balance changes for a sender-pays multi-hop transfer.
        # Walks the path backwards (receiver to sender), accumulating fees.
        #
        # @param hops [Array<Hash>] ordered sender→receiver, each:
        #   { sender:, receiver:, balance:, creditline_received: }
        #   balance is from sender's perspective on that hop
        # @param value [BigDecimal] amount the final receiver should get
        # @param max_fee [BigDecimal] maximum acceptable total fee
        # @param capacity_imbalance_fee_divisor [Integer] fee divisor (0 = no fees)
        # @return [Hash] {
        #   total_fees:,
        #   hop_results: [{ sender:, receiver:, value:, fee:, new_balance: }, ...]
        # }
        # @raise [InsufficientCapacity] if any hop lacks capacity
        # @raise [MaxFeeExceeded] if total fees exceed max_fee
        def execute_sender_pays(hops:, value:, max_fee:, capacity_imbalance_fee_divisor:)
          raise ArgumentError, "Path must have at least one hop" if hops.empty?
          raise ArgumentError, "Value must be positive" unless value > 0

          total_fees = BigDecimal("0")
          forwarded_value = value
          hop_results = []

          # Walk backwards: last hop first (receiver end)
          hops.reverse_each.with_index do |hop, reverse_index|
            if reverse_index == 0
              # Final receiver — no fee on this hop
              fee = BigDecimal("0")
            else
              imbalance = FeeCalculator.imbalance_generated(
                value: forwarded_value,
                balance: hop[:balance]
              )
              fee = FeeCalculator.calculate_fees_reverse(
                imbalance_generated: imbalance,
                capacity_imbalance_fee_divisor: capacity_imbalance_fee_divisor
              )
              forwarded_value += fee
              total_fees += fee

              raise MaxFeeExceeded.new(total_fees: total_fees, max_fee: max_fee) if total_fees > max_fee
            end

            # Apply the transfer on this hop
            new_balance = BalanceMath.apply_direct_transfer(
              balance: hop[:balance],
              value: forwarded_value,
              creditline_received: hop[:creditline_received]
            )

            hop_results.unshift({
              sender: hop[:sender],
              receiver: hop[:receiver],
              value: forwarded_value,
              fee: fee,
              new_balance: new_balance
            })
          end

          { total_fees: total_fees, hop_results: hop_results }
        end

        # Compute balance changes for a receiver-pays multi-hop transfer.
        # Walks the path forwards (sender to receiver), subtracting fees.
        #
        # @param hops [Array<Hash>] ordered sender→receiver, each:
        #   { sender:, receiver:, balance:, creditline_received: }
        # @param value [BigDecimal] amount the sender sends
        # @param max_fee [BigDecimal] maximum acceptable total fee
        # @param capacity_imbalance_fee_divisor [Integer] fee divisor (0 = no fees)
        # @return [Hash] same as execute_sender_pays
        def execute_receiver_pays(hops:, value:, max_fee:, capacity_imbalance_fee_divisor:)
          raise ArgumentError, "Path must have at least one hop" if hops.empty?
          raise ArgumentError, "Value must be positive" unless value > 0

          total_fees = BigDecimal("0")
          forwarded_value = value
          hop_results = []

          hops.each_with_index do |hop, index|
            # Apply the transfer on this hop
            new_balance = BalanceMath.apply_direct_transfer(
              balance: hop[:balance],
              value: forwarded_value,
              creditline_received: hop[:creditline_received]
            )

            if index == hops.size - 1
              # Final receiver — no fee deducted
              fee = BigDecimal("0")
            else
              imbalance = FeeCalculator.imbalance_generated(
                value: forwarded_value,
                balance: hop[:balance]
              )
              fee = FeeCalculator.calculate_fees(
                imbalance_generated: imbalance,
                capacity_imbalance_fee_divisor: capacity_imbalance_fee_divisor
              )
              forwarded_value -= fee
              total_fees += fee

              raise MaxFeeExceeded.new(total_fees: total_fees, max_fee: max_fee) if total_fees > max_fee
            end

            hop_results << {
              sender: hop[:sender],
              receiver: hop[:receiver],
              value: forwarded_value,
              fee: fee,
              new_balance: new_balance
            }
          end

          { total_fees: total_fees, hop_results: hop_results }
        end

        # Validate that a path is structurally valid for a multi-hop transfer.
        #
        # @param path [Array<String>] ordered list of addresses from sender to receiver
        # @return [Hash] { valid: true } or { valid: false, reason: "..." }
        def validate_path(path)
          return { valid: false, reason: "Path must have at least 2 addresses" } if path.size < 2
          return { valid: false, reason: "Path contains duplicate consecutive addresses" } if path.each_cons(2).any? { |a, b| a == b }
          { valid: true }
        end
      end
    end
  end
end
