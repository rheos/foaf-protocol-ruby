# frozen_string_literal: true

# Credloop detection and cancellation service.
# Loads the debt graph from trustlines, finds cancellable cycles,
# and executes cancellations as atomic multi-hop transfers.

class CredloopService
  # Find all cancellable credit loops in a network.
  #
  # @param network [CurrencyNetwork]
  # @param max_length [Integer] maximum cycle length (default: network max_hops)
  # @return [Array<Hash>] each: { path:, cancellable_amount:, usernames: }
  def self.find_loops(network, max_length: nil)
    max_length ||= network.max_hops
    edges = build_debt_edges(network)
    loops = Foaf::Trustline::Protocol::CredloopDetector.find_loops(edges, max_length: max_length)
    loops
  end

  # Find and cancel the single best (highest value) credit loop.
  #
  # @param network [CurrencyNetwork]
  # @return [Hash, nil] { operation:, path:, amount:, events: } or nil if no loops
  def self.cancel_best_loop(network)
    edges = build_debt_edges(network)
    loop_info = Foaf::Trustline::Protocol::CredloopDetector.find_best_loop(edges)
    return nil unless loop_info

    cancel_loop(network, loop_info)
  end

  # Cancel a specific credit loop.
  #
  # @param network [CurrencyNetwork]
  # @param loop_info [Hash] { path:, cancellable_amount: }
  # @return [Hash] { operation:, path:, amount:, events: }
  def self.cancel_loop(network, loop_info)
    transfer_path = Foaf::Trustline::Protocol::CredloopDetector.build_transfer_path(loop_info[:path])

    # Execute as a multi-hop transfer around the cycle
    # The "sender" is the first node, "receiver" is also the first node (it's a cycle)
    # But we use TransferService with the circular path
    # Each hop reduces debt — net zero effect on everyone
    result = TransferService.execute(
      network: network,
      sender_address: transfer_path.first,
      receiver_address: transfer_path.first, # same — it's a cycle
      value: loop_info[:cancellable_amount],
      path: transfer_path,
      extra_data: { type: "credloop_cancellation", cycle_length: loop_info[:path].size }.to_json
    )

    Rails.logger.info(
      "[Credloop] Cancelled loop: #{loop_info[:path].join(' → ')} → #{loop_info[:path].first} " \
      "amount=#{loop_info[:cancellable_amount]}"
    )

    result
  end

  # Cancel all detected credit loops in a network (iterative).
  # Keeps finding and cancelling until no more loops exist.
  #
  # @param network [CurrencyNetwork]
  # @param max_iterations [Integer] safety limit
  # @return [Array<Hash>] list of cancelled loops
  def self.cancel_all_loops(network, max_iterations: 100)
    cancelled = []

    max_iterations.times do
      result = cancel_best_loop(network)
      break unless result
      cancelled << result
    end

    Rails.logger.info("[Credloop] Cancelled #{cancelled.size} loops in network #{network.address}")
    cancelled
  end

  private

  # Build the directed debt graph from trustline balances.
  # An edge from A → B means A owes B.
  def self.build_debt_edges(network)
    edges = []

    Foaf::TrustlineRecord.in_network(network.id).each do |tl|
      if tl.balance > 0
        # Positive balance = B owes A (FOAF convention)
        edges << { from: tl.user_b_address, to: tl.user_a_address, amount: tl.balance }
      elsif tl.balance < 0
        # Negative balance = A owes B
        edges << { from: tl.user_a_address, to: tl.user_b_address, amount: -tl.balance }
      end
    end

    edges
  end
end
