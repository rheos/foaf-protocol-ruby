# frozen_string_literal: true

# Test vectors for trustline update state machine.
# Mirrors CurrencyNetworkBasic._updateTrustline two-stage pattern.

require_relative "../../foaf_trustline/lib/foaf/trustline/protocol"

RSpec.describe Foaf::Trustline::Protocol::TrustlineStateMachine do
  let(:sm) { described_class }

  describe ".evaluate_update" do
    let(:alice) { "0xalice" }
    let(:bob) { "0xbob" }

    context "pure reduction (always immediate)" do
      it "applies immediately when reducing given creditline" do
        result = sm.evaluate_update(
          current: { creditline_given: 100, creditline_received: 50, is_frozen: false },
          requested: { creditline_given: 80, creditline_received: 50, is_frozen: false },
          pending_request: nil,
          initiator: alice,
          counterparty: bob
        )
        expect(result[:action]).to eq(:apply_immediately)
        expect(result[:new_state][:creditline_given]).to eq(80)
      end

      it "applies immediately when reducing both creditlines" do
        result = sm.evaluate_update(
          current: { creditline_given: 100, creditline_received: 50, is_frozen: false },
          requested: { creditline_given: 50, creditline_received: 25, is_frozen: false },
          pending_request: nil,
          initiator: alice,
          counterparty: bob
        )
        expect(result[:action]).to eq(:apply_immediately)
      end
    end

    context "increase requires request" do
      it "creates request when increasing given creditline" do
        result = sm.evaluate_update(
          current: { creditline_given: 50, creditline_received: 50, is_frozen: false },
          requested: { creditline_given: 100, creditline_received: 50, is_frozen: false },
          pending_request: nil,
          initiator: alice,
          counterparty: bob
        )
        expect(result[:action]).to eq(:create_request)
        expect(result[:request][:initiator]).to eq(alice)
      end

      it "creates request for new trustline (all zeros to any value)" do
        result = sm.evaluate_update(
          current: { creditline_given: 0, creditline_received: 0, is_frozen: false },
          requested: { creditline_given: 100, creditline_received: 50, is_frozen: false },
          pending_request: nil,
          initiator: alice,
          counterparty: bob
        )
        expect(result[:action]).to eq(:create_request)
      end
    end

    context "accepting counterparty request" do
      it "accepts when terms are within counterparty proposal" do
        result = sm.evaluate_update(
          current: { creditline_given: 0, creditline_received: 0, is_frozen: false },
          requested: { creditline_given: 50, creditline_received: 100, is_frozen: false },
          pending_request: {
            creditline_given: 100,
            creditline_received: 50,
            is_frozen: false,
            initiator: bob
          },
          initiator: alice,
          counterparty: bob
        )
        expect(result[:action]).to eq(:accept_request)
      end

      it "accepts when terms are more conservative than proposal" do
        result = sm.evaluate_update(
          current: { creditline_given: 0, creditline_received: 0, is_frozen: false },
          requested: { creditline_given: 30, creditline_received: 80, is_frozen: false },
          pending_request: {
            creditline_given: 100,
            creditline_received: 50,
            is_frozen: false,
            initiator: bob
          },
          initiator: alice,
          counterparty: bob
        )
        expect(result[:action]).to eq(:accept_request)
      end

      it "creates new request when terms exceed counterparty proposal" do
        result = sm.evaluate_update(
          current: { creditline_given: 0, creditline_received: 0, is_frozen: false },
          requested: { creditline_given: 200, creditline_received: 100, is_frozen: false },
          pending_request: {
            creditline_given: 100,
            creditline_received: 50,
            is_frozen: false,
            initiator: bob
          },
          initiator: alice,
          counterparty: bob
        )
        expect(result[:action]).to eq(:create_request)
      end
    end

    context "frozen trustlines" do
      it "rejects update on frozen trustline if not unfreezing" do
        result = sm.evaluate_update(
          current: { creditline_given: 100, creditline_received: 50, is_frozen: true },
          requested: { creditline_given: 80, creditline_received: 50, is_frozen: true },
          pending_request: nil,
          initiator: alice,
          counterparty: bob
        )
        expect(result[:action]).to eq(:reject)
      end
    end

    context "zero trustline prevention" do
      it "rejects opening a zero trustline" do
        result = sm.evaluate_update(
          current: { creditline_given: 0, creditline_received: 0, is_frozen: false },
          requested: { creditline_given: 0, creditline_received: 0, is_frozen: false },
          pending_request: nil,
          initiator: alice,
          counterparty: bob
        )
        expect(result[:action]).to eq(:reject)
      end
    end
  end

  describe ".validate_close" do
    it "allows close when balance is zero" do
      expect(sm.validate_close(balance: BigDecimal("0"), is_frozen: false))
        .to eq({ valid: true })
    end

    it "rejects close when balance is non-zero" do
      result = sm.validate_close(balance: BigDecimal("25"), is_frozen: false)
      expect(result[:valid]).to be false
    end

    it "rejects close when frozen" do
      result = sm.validate_close(balance: BigDecimal("0"), is_frozen: true)
      expect(result[:valid]).to be false
    end
  end

  describe ".canonical_order" do
    it "puts lower address as user_a" do
      result = sm.canonical_order("0xbbb", "0xaaa")
      expect(result[:user_a]).to eq("0xaaa")
      expect(result[:user_b]).to eq("0xbbb")
      expect(result[:first_is_a]).to be false
    end

    it "preserves order when already canonical" do
      result = sm.canonical_order("0xaaa", "0xbbb")
      expect(result[:first_is_a]).to be true
    end
  end
end
