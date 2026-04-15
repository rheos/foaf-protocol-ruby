# frozen_string_literal: true

module Foaf
  module Trustline
    module Protocol
      # Pure balance math for trustline operations.
      # Mirrors CurrencyNetworkBasic.sol — no Rails, no I/O, no database.
      #
      # Balance convention (matches Trustlines):
      #   Trustline between A and B (canonical: A < B)
      #   balance > 0  →  B owes A
      #   balance < 0  →  A owes B
      #   balance(B, A) = -balance(A, B)
      #
      # All amounts are BigDecimal for precision.
      module BalanceMath
        module_function

        # Apply a direct transfer from sender to receiver on a trustline.
        # Returns the new balance.
        #
        # Mirrors CurrencyNetworkBasic._applyDirectTransfer
        #
        # @param balance [BigDecimal] current trustline balance (from sender's perspective)
        # @param value [BigDecimal] amount to transfer (must be positive)
        # @param creditline_received [BigDecimal] credit limit receiver has given to sender
        #   (i.e., how much sender is allowed to owe receiver)
        # @return [BigDecimal] new balance after transfer
        # @raise [InsufficientCapacity] if transfer exceeds creditline
        def apply_direct_transfer(balance:, value:, creditline_received:)
          raise ArgumentError, "Transfer value must be positive" unless value > 0

          new_balance = balance - value

          # Check creditline not exceeded: sender can't owe more than creditline_received
          # In Solidity: require(-newBalance <= creditlineReceived)
          if -new_balance > creditline_received
            raise InsufficientCapacity.new(
              requested: value,
              available: capacity(balance: balance, creditline_received: creditline_received)
            )
          end

          new_balance
        end

        # Calculate available capacity for a transfer from sender's perspective.
        #
        # capacity = creditline_received + balance
        #   If balance > 0 (receiver owes sender), sender has MORE capacity
        #   If balance < 0 (sender owes receiver), sender has LESS capacity
        #
        # @param balance [BigDecimal] current balance from sender's perspective
        # @param creditline_received [BigDecimal] credit limit receiver gives sender
        # @return [BigDecimal] maximum transferable amount (clamped to 0 minimum)
        def capacity(balance:, creditline_received:)
          [creditline_received + balance, BigDecimal("0")].max
        end

        # Calculate the balance from a specific user's perspective.
        # If the user is the canonical "first" user (user_a), return as-is.
        # If the user is user_b, negate.
        #
        # @param balance [BigDecimal] canonical balance (from user_a's perspective)
        # @param user_is_a [Boolean] true if querying user is user_a
        # @return [BigDecimal] balance from querying user's perspective
        def balance_for_user(balance:, user_is_a:)
          user_is_a ? balance : -balance
        end

        # Determine the creditline the querying user can draw on
        # (the credit extended TO them BY the counterparty).
        #
        # @param creditline_a_to_b [BigDecimal] credit A gives to B
        # @param creditline_b_to_a [BigDecimal] credit B gives to A
        # @param user_is_a [Boolean] true if querying user is user_a
        # @return [BigDecimal] creditline the querying user receives
        def creditline_received_for_user(creditline_a_to_b:, creditline_b_to_a:, user_is_a:)
          # If user is A, they receive the creditline B gives to A
          # If user is B, they receive the creditline A gives to B
          user_is_a ? creditline_b_to_a : creditline_a_to_b
        end

        # Determine the creditline the querying user has given to the counterparty.
        #
        # @param creditline_a_to_b [BigDecimal] credit A gives to B
        # @param creditline_b_to_a [BigDecimal] credit B gives to A
        # @param user_is_a [Boolean] true if querying user is user_a
        # @return [BigDecimal] creditline the querying user has given
        def creditline_given_for_user(creditline_a_to_b:, creditline_b_to_a:, user_is_a:)
          user_is_a ? creditline_a_to_b : creditline_b_to_a
        end

        # Validate that a transfer can proceed.
        # Returns { valid: true } or { valid: false, reason: "..." }
        #
        # @param balance [BigDecimal] balance from sender's perspective
        # @param value [BigDecimal] amount to transfer
        # @param creditline_received [BigDecimal] credit limit for sender
        # @return [Hash] validation result
        def validate_transfer(balance:, value:, creditline_received:)
          return { valid: false, reason: "Transfer value must be positive" } unless value > 0

          available = capacity(balance: balance, creditline_received: creditline_received)
          if value > available
            { valid: false, reason: "Insufficient capacity", available: available, requested: value }
          else
            { valid: true, available: available }
          end
        end
      end

      # Raised when a transfer exceeds available capacity on a trustline.
      class InsufficientCapacity < StandardError
        attr_reader :requested, :available

        def initialize(requested:, available:)
          @requested = requested
          @available = available
          super("Insufficient capacity: requested #{requested}, available #{available}")
        end
      end
    end
  end
end
