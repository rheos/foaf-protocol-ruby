# frozen_string_literal: true

module Foaf
  module Trustline
    module Protocol
      # Trustline update state machine.
      # Mirrors the two-stage accept pattern from CurrencyNetworkBasic._updateTrustline.
      # No Rails, no I/O, no database.
      #
      # Rules (from Trustlines):
      #   1. Reductions to creditlines given are always unilateral and immediate.
      #      You can always trust someone less.
      #   2. Increases to creditline received require counterparty acceptance.
      #      You can't force someone to extend you more credit.
      #   3. If a pending request exists from the counterparty, and the new values
      #      are within their proposed terms, it auto-accepts.
      module TrustlineStateMachine
        module_function

        # Determine the outcome of a trustline update request.
        #
        # @param current [Hash] current trustline state:
        #   { creditline_given:, creditline_received:, is_frozen: }
        # @param requested [Hash] what the initiator wants:
        #   { creditline_given:, creditline_received:, is_frozen: }
        # @param pending_request [Hash, nil] existing pending request from counterparty:
        #   { creditline_given:, creditline_received:, is_frozen:, initiator: }
        #   Note: given/received are from the COUNTERPARTY's perspective
        # @param initiator [String] address of the user making this call
        # @param counterparty [String] address of the other user
        #
        # @return [Hash] one of:
        #   { action: :apply_immediately, new_state: { ... } }
        #   { action: :create_request, request: { ... } }
        #   { action: :accept_request, new_state: { ... } }
        #   { action: :reject, reason: "..." }
        def evaluate_update(current:, requested:, pending_request:, initiator:, counterparty:)
          # Frozen trustlines can only be unfrozen
          if current[:is_frozen]
            if requested[:is_frozen]
              return { action: :reject, reason: "Trustline is frozen, it cannot be updated unless unfrozen" }
            end
          end

          # Check if this is a pure reduction (always allowed immediately)
          if pure_reduction?(current: current, requested: requested)
            # Prevent opening a zero trustline (Trustlines prevents this)
            if trustline_is_empty?(current) && trustline_is_empty?(requested)
              return { action: :reject, reason: "Cannot open zero trustline" }
            end

            return {
              action: :apply_immediately,
              new_state: {
                creditline_given: requested[:creditline_given],
                creditline_received: requested[:creditline_received],
                is_frozen: requested[:is_frozen]
              }
            }
          end

          # Check if we can accept an existing counterparty request
          if pending_request && pending_request[:initiator] == counterparty
            if request_acceptable?(requested: requested, pending: pending_request)
              return {
                action: :accept_request,
                new_state: {
                  # Use the more conservative values (what the acceptor requested)
                  creditline_given: requested[:creditline_given],
                  creditline_received: requested[:creditline_received],
                  is_frozen: requested[:is_frozen]
                }
              }
            end
          end

          # Otherwise, create/update a request for counterparty approval
          {
            action: :create_request,
            request: {
              creditline_given: requested[:creditline_given],
              creditline_received: requested[:creditline_received],
              is_frozen: requested[:is_frozen],
              initiator: initiator
            }
          }
        end

        # Validate that a trustline can be closed.
        #
        # @param balance [BigDecimal] current balance
        # @param is_frozen [Boolean] whether trustline is frozen
        # @return [Hash] { valid: true } or { valid: false, reason: "..." }
        def validate_close(balance:, is_frozen:)
          if is_frozen
            return { valid: false, reason: "Frozen trustline cannot be closed" }
          end

          if balance != 0
            return { valid: false, reason: "Trustline can only be closed if balance is zero" }
          end

          { valid: true }
        end

        # Determine canonical ordering for a pair of user addresses.
        # The lower address is always user_a.
        #
        # @param address_1 [String] first address
        # @param address_2 [String] second address
        # @return [Hash] { user_a:, user_b:, first_is_a: }
        def canonical_order(address_1, address_2)
          if address_1 < address_2
            { user_a: address_1, user_b: address_2, first_is_a: true }
          else
            { user_a: address_2, user_b: address_1, first_is_a: false }
          end
        end

        # --- Private helpers ---

        # A pure reduction: all values are <= current, and trustline is not frozen.
        def pure_reduction?(current:, requested:)
          requested[:creditline_given] <= current[:creditline_given] &&
            requested[:creditline_received] <= current[:creditline_received] &&
            requested[:is_frozen] == current[:is_frozen] &&
            !current[:is_frozen]
        end

        # Check if the initiator's request is acceptable given a pending counterparty request.
        # The acceptor's terms must be within (<=) what the counterparty proposed.
        #
        # Counterparty's given = acceptor's received, and vice versa.
        def request_acceptable?(requested:, pending:)
          # Acceptor's creditline_received <= counterparty's creditline_given
          requested[:creditline_received] <= pending[:creditline_given] &&
            # Acceptor's creditline_given <= counterparty's creditline_received
            requested[:creditline_given] <= pending[:creditline_received] &&
            # Frozen state must match
            requested[:is_frozen] == pending[:is_frozen]
        end

        def trustline_is_empty?(state)
          state[:creditline_given] == 0 &&
            state[:creditline_received] == 0
        end

        private_class_method :pure_reduction?, :request_acceptable?, :trustline_is_empty?
      end
    end
  end
end
