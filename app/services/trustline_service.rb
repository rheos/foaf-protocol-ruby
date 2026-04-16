# frozen_string_literal: true

# Trustline lifecycle — open, update, close.
# Each method is like calling a Scrypto blueprint method on the CurrencyNetwork component.
# State changes are atomic. Locking prevents concurrent mutation.

class TrustlineService
  # Open or update a trustline (two-stage pattern).
  # Mirrors CurrencyNetworkBasic.updateTrustline / updateCreditlimits
  #
  # The creditor is the caller (msg.sender equivalent).
  # Reductions are immediate. Increases require counterparty acceptance.
  #
  # @param network [CurrencyNetwork]
  # @param creditor_address [String] the identity making this call
  # @param debtor_address [String] the counterparty
  # @param creditline_given [BigDecimal] credit creditor extends to debtor
  # @param creditline_received [BigDecimal] credit creditor wants from debtor
  # @return [Hash] { action:, trustline:, request: }
  def self.update_trustline(network:, creditor_address:, debtor_address:,
                            creditline_given:, creditline_received:)
    raise "Network is frozen" if network.frozen?
    raise "Cannot create trustline with self" if creditor_address == debtor_address

    # Canonical ordering
    ordering = Foaf::Trustline::Protocol::TrustlineStateMachine.canonical_order(
      creditor_address, debtor_address
    )

    ActiveRecord::Base.transaction do
      trustline = Foaf::TrustlineRecord
        .in_network(network.id)
        .between(creditor_address, debtor_address)
        .lock("FOR UPDATE")
        .first

      # Translate caller's given/received into canonical a/b terms
      creditor_is_a = ordering[:first_is_a] ? (creditor_address == ordering[:user_a]) : (creditor_address == ordering[:user_a])
      creditor_is_a = creditor_address == ordering[:user_a]

      if trustline
        current = {
          creditline_given: creditor_is_a ? trustline.creditline_given : trustline.creditline_received,
          creditline_received: creditor_is_a ? trustline.creditline_received : trustline.creditline_given,
          is_frozen: trustline.is_frozen
        }
      else
        current = { creditline_given: 0, creditline_received: 0, is_frozen: false }
      end

      requested = {
        creditline_given: creditline_given,
        creditline_received: creditline_received,
        is_frozen: false
      }

      pending_request = trustline&.trustline_update_requests&.first
      pending_hash = if pending_request
        {
          creditline_given: pending_request.creditline_given,
          creditline_received: pending_request.creditline_received,
          is_frozen: pending_request.is_frozen,
          initiator: pending_request.initiator_address
        }
      end

      result = Foaf::Trustline::Protocol::TrustlineStateMachine.evaluate_update(
        current: current,
        requested: requested,
        pending_request: pending_hash,
        initiator: creditor_address,
        counterparty: debtor_address
      )

      case result[:action]
      when :apply_immediately, :accept_request
        # Apply the new state
        new_given = creditor_is_a ? result[:new_state][:creditline_given] : result[:new_state][:creditline_received]
        new_received = creditor_is_a ? result[:new_state][:creditline_received] : result[:new_state][:creditline_given]

        if trustline
          trustline.update!(
            creditline_given: new_given,
            creditline_received: new_received,
            is_frozen: result[:new_state][:is_frozen]
          )
        else
          trustline = Foaf::TrustlineRecord.create!(
            currency_network: network,
            user_a_address: ordering[:user_a],
            user_b_address: ordering[:user_b],
            creditline_given: new_given,
            creditline_received: new_received,
            is_frozen: false
          )
        end

        # Clear any pending request
        pending_request&.destroy!

        # Record operation
        op = Operation.create!(
          operation_type: result[:action] == :accept_request ? "trustline_update_accept" : "trustline_update",
          module_name: "trustline",
          currency_network: network,
          actor_address: creditor_address,
          inputs: {
            creditor: creditor_address,
            debtor: debtor_address,
            creditline_given: creditline_given.to_f,
            creditline_received: creditline_received.to_f
          },
          status: "applied"
        )

        # Emit TrustlineUpdate event
        TrustlineEvent.create!(
          operation: op,
          currency_network: network,
          event_type: "TrustlineUpdate",
          from_address: creditor_address,
          to_address: debtor_address,
          creditline_given: creditline_given,
          creditline_received: creditline_received,
          is_frozen: false
        )

        { action: result[:action], trustline: trustline }

      when :create_request
        trustline ||= Foaf::TrustlineRecord.create!(
          currency_network: network,
          user_a_address: ordering[:user_a],
          user_b_address: ordering[:user_b],
          creditline_given: 0,
          creditline_received: 0,
          is_frozen: false
        )

        # Upsert the request
        req = trustline.trustline_update_requests.first_or_initialize
        req.assign_attributes(
          creditline_given: creditline_given,
          creditline_received: creditline_received,
          is_frozen: false,
          initiator_address: creditor_address
        )
        req.save!

        # Record operation
        op = Operation.create!(
          operation_type: "trustline_update_request",
          module_name: "trustline",
          currency_network: network,
          actor_address: creditor_address,
          inputs: {
            creditor: creditor_address,
            debtor: debtor_address,
            creditline_given: creditline_given.to_f,
            creditline_received: creditline_received.to_f
          },
          status: "applied"
        )

        # Emit TrustlineUpdateRequest event
        TrustlineEvent.create!(
          operation: op,
          currency_network: network,
          event_type: "TrustlineUpdateRequest",
          from_address: creditor_address,
          to_address: debtor_address,
          creditline_given: creditline_given,
          creditline_received: creditline_received,
          is_frozen: false
        )

        { action: :create_request, trustline: trustline, request: req }

      when :reject
        raise result[:reason]
      end
    end
  end

  # Cancel a pending trustline update request.
  def self.cancel_update(network:, initiator_address:, counterparty_address:)
    ActiveRecord::Base.transaction do
      trustline = Foaf::TrustlineRecord
        .in_network(network.id)
        .between(initiator_address, counterparty_address)
        .lock("FOR UPDATE")
        .first!

      request = trustline.trustline_update_requests
        .where(initiator_address: initiator_address)
        .first!

      request.destroy!

      op = Operation.create!(
        operation_type: "trustline_update_cancel",
        module_name: "trustline",
        currency_network: network,
        actor_address: initiator_address,
        inputs: { counterparty: counterparty_address },
        status: "applied"
      )

      TrustlineEvent.create!(
        operation: op,
        currency_network: network,
        event_type: "TrustlineUpdateCancel",
        from_address: initiator_address,
        to_address: counterparty_address
      )

      { action: :cancelled, trustline: trustline }
    end
  end

  # Close a trustline (balance must be zero).
  def self.close_trustline(network:, closer_address:, counterparty_address:)
    ActiveRecord::Base.transaction do
      trustline = Foaf::TrustlineRecord
        .in_network(network.id)
        .between(closer_address, counterparty_address)
        .lock("FOR UPDATE")
        .first!

      validation = Foaf::Trustline::Protocol::TrustlineStateMachine.validate_close(
        balance: trustline.balance,
        is_frozen: trustline.is_frozen
      )

      raise validation[:reason] unless validation[:valid]

      # Destroy the trustline and any pending requests
      trustline.trustline_update_requests.destroy_all
      trustline.destroy!

      op = Operation.create!(
        operation_type: "trustline_close",
        module_name: "trustline",
        currency_network: network,
        actor_address: closer_address,
        inputs: { counterparty: counterparty_address },
        status: "applied"
      )

      TrustlineEvent.create!(
        operation: op,
        currency_network: network,
        event_type: "TrustlineUpdate",
        from_address: closer_address,
        to_address: counterparty_address,
        creditline_given: 0,
        creditline_received: 0,
        is_frozen: false
      )

      { action: :closed }
    end
  end

  # Serialize a trustline from a specific user's perspective.
  # Mirrors Trustlines relay TrustlineSchema.
  def self.serialize(trustline, from_address: nil)
    user_is_a = trustline.user_is_a?(from_address) if from_address

    if from_address
      balance = Foaf::Trustline::Protocol::BalanceMath.balance_for_user(
        balance: trustline.balance, user_is_a: user_is_a
      )
      given = Foaf::Trustline::Protocol::BalanceMath.creditline_given_for_user(
        creditline_a_to_b: trustline.creditline_given,
        creditline_b_to_a: trustline.creditline_received,
        user_is_a: user_is_a
      )
      received = Foaf::Trustline::Protocol::BalanceMath.creditline_received_for_user(
        creditline_a_to_b: trustline.creditline_given,
        creditline_b_to_a: trustline.creditline_received,
        user_is_a: user_is_a
      )
      left_given = [given + balance, BigDecimal("0")].max
      left_received = Foaf::Trustline::Protocol::BalanceMath.capacity(
        balance: balance, creditline_received: received
      )

      {
        id: trustline.id,
        address: trustline.currency_network.address,
        currencyNetwork: trustline.currency_network.address,
        user: from_address,
        counterParty: trustline.counterparty(from_address),
        given: given.to_f,
        received: received.to_f,
        leftGiven: left_given.to_f,
        leftReceived: left_received.to_f,
        balance: balance.to_f,
        interestRateGiven: trustline.interest_rate_given,
        interestRateReceived: trustline.interest_rate_received,
        isFrozen: trustline.is_frozen
      }
    else
      {
        id: trustline.id,
        address: trustline.currency_network.address,
        currencyNetwork: trustline.currency_network.address,
        userA: trustline.user_a_address,
        userB: trustline.user_b_address,
        creditlineGiven: trustline.creditline_given.to_f,
        creditlineReceived: trustline.creditline_received.to_f,
        balance: trustline.balance.to_f,
        interestRateGiven: trustline.interest_rate_given,
        interestRateReceived: trustline.interest_rate_received,
        isFrozen: trustline.is_frozen
      }
    end
  end
end
