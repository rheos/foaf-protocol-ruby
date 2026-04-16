# frozen_string_literal: true

module Foaf
  module Trustline
    module Protocol
      # Credloop (credit loop) detection — finds cycles in the debt graph
      # that can be cancelled as atomic multi-hop transfers with zero net payment.
      #
      # Off-ledger forever, like Trustlines' relay. Only the resulting
      # cancellation is a protocol operation.
      #
      # No Rails, no I/O, no database. Takes a list of edges, returns cycles.
      #
      # Debt graph convention:
      #   An edge from A → B with amount X means A owes B $X.
      #   A cycle A → B → C → A means the debt flows in a circle
      #   and can be reduced by min(debts along the cycle).
      module CredloopDetector
        module_function

        # Find all cancellable credit loops in a debt graph.
        #
        # @param edges [Array<Hash>] each: { from:, to:, amount: }
        #   from owes to the given amount. Only include edges where amount > 0.
        # @param max_length [Integer] maximum cycle length to search for (default: 10)
        # @return [Array<Hash>] each: { path: [addr, ...], cancellable_amount: BigDecimal }
        #   path is ordered: path[0] owes path[1] owes ... owes path[0]
        def find_loops(edges, max_length: 10)
          graph = build_adjacency_list(edges)
          nodes = graph.keys.sort
          loops = []
          visited_cycles = Set.new

          nodes.each do |start_node|
            dfs_find_cycles(
              graph: graph,
              start: start_node,
              current: start_node,
              path: [start_node],
              amounts: {},
              visited: Set.new([start_node]),
              loops: loops,
              visited_cycles: visited_cycles,
              max_length: max_length
            )
          end

          loops
        end

        # Find the single best (highest value) cancellable loop.
        # More efficient than finding all loops when you just want to cancel one.
        #
        # @param edges [Array<Hash>] same as find_loops
        # @param max_length [Integer] maximum cycle length
        # @return [Hash, nil] { path:, cancellable_amount: } or nil
        def find_best_loop(edges, max_length: 10)
          loops = find_loops(edges, max_length: max_length)
          loops.max_by { |l| l[:cancellable_amount] }
        end

        # Calculate the cancellable amount for a given cycle path.
        #
        # @param path [Array<String>] addresses forming the cycle (last → first closes it)
        # @param edge_amounts [Hash] { [from, to] => BigDecimal } debt amounts
        # @return [BigDecimal] minimum debt along the cycle (the cancellable amount)
        def cancellable_amount(path, edge_amounts)
          min = nil
          path.each_cons(2) do |from, to|
            amount = edge_amounts[[from, to]] || BigDecimal("0")
            min = amount if min.nil? || amount < min
          end
          # Close the cycle: last → first
          closing_amount = edge_amounts[[path.last, path.first]] || BigDecimal("0")
          min = closing_amount if min.nil? || closing_amount < min
          min || BigDecimal("0")
        end

        # Build the transfer path for cancelling a credloop.
        # The debt cycle goes A→B→C→A (A owes B owes C owes A).
        # To REDUCE debts, payments flow in the REVERSE direction:
        # A→C→B→A (each creditor pays back to reduce the debtor's obligation).
        #
        # @param cycle_path [Array<String>] the debt cycle (without repeating the start)
        # @return [Array<String>] transfer path (reversed + circular)
        def build_transfer_path(cycle_path)
          reversed = [cycle_path.first] + cycle_path[1..].reverse
          reversed + [reversed.first]
        end

        private

        def self.build_adjacency_list(edges)
          graph = Hash.new { |h, k| h[k] = {} }
          edges.each do |edge|
            from = edge[:from]
            to = edge[:to]
            amount = edge[:amount]
            next unless amount > 0
            graph[from][to] = amount
            # Ensure 'to' node exists in graph even if it has no outgoing edges
            graph[to] unless graph.key?(to)
          end
          graph
        end

        def self.dfs_find_cycles(graph:, start:, current:, path:, amounts:,
                                  visited:, loops:, visited_cycles:, max_length:)
          return if path.size > max_length

          neighbors = graph[current] || {}
          neighbors.each do |neighbor, amount|
            if neighbor == start && path.size >= 3
              # Found a cycle back to start
              cycle_key = normalize_cycle(path)
              unless visited_cycles.include?(cycle_key)
                visited_cycles.add(cycle_key)

                # Calculate cancellable amount (minimum debt along cycle)
                edge_amounts = amounts.merge([current, neighbor] => amount)
                min_amount = edge_amounts.values.min

                if min_amount > 0
                  loops << {
                    path: path.dup,
                    cancellable_amount: min_amount
                  }
                end
              end
            elsif !visited.include?(neighbor)
              visited.add(neighbor)
              dfs_find_cycles(
                graph: graph,
                start: start,
                current: neighbor,
                path: path + [neighbor],
                amounts: amounts.merge([current, neighbor] => amount),
                visited: visited,
                loops: loops,
                visited_cycles: visited_cycles,
                max_length: max_length
              )
              visited.delete(neighbor)
            end
          end
        end

        # Normalize a cycle so the same cycle found from different starting
        # nodes is recognized as identical. Rotate to start with the
        # lexicographically smallest node.
        def self.normalize_cycle(path)
          min_idx = path.each_with_index.min_by { |node, _| node }[1]
          rotated = path.rotate(min_idx)
          rotated.join("→")
        end

        private_class_method :build_adjacency_list, :dfs_find_cycles, :normalize_cycle
      end
    end
  end
end
