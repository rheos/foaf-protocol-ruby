# frozen_string_literal: true

# These tests are the language-agnostic test vectors.
# Any future implementation (Rust, Scrypto) must pass the same cases.

require_relative "../../foaf_trustline/lib/foaf/trustline/protocol"

RSpec.describe Foaf::Trustline::Protocol::BalanceMath do
  let(:bm) { described_class }

  describe ".apply_direct_transfer" do
    it "subtracts value from balance" do
      result = bm.apply_direct_transfer(
        balance: BigDecimal("0"),
        value: BigDecimal("25"),
        creditline_received: BigDecimal("100")
      )
      expect(result).to eq(BigDecimal("-25"))
    end

    it "works when receiver already owes sender (positive balance)" do
      result = bm.apply_direct_transfer(
        balance: BigDecimal("50"),
        value: BigDecimal("25"),
        creditline_received: BigDecimal("100")
      )
      expect(result).to eq(BigDecimal("25"))
    end

    it "allows transfer up to exact capacity" do
      result = bm.apply_direct_transfer(
        balance: BigDecimal("0"),
        value: BigDecimal("100"),
        creditline_received: BigDecimal("100")
      )
      expect(result).to eq(BigDecimal("-100"))
    end

    it "raises InsufficientCapacity when exceeding creditline" do
      expect {
        bm.apply_direct_transfer(
          balance: BigDecimal("0"),
          value: BigDecimal("101"),
          creditline_received: BigDecimal("100")
        )
      }.to raise_error(Foaf::Trustline::Protocol::InsufficientCapacity)
    end

    it "raises InsufficientCapacity when already at limit" do
      expect {
        bm.apply_direct_transfer(
          balance: BigDecimal("-100"),
          value: BigDecimal("1"),
          creditline_received: BigDecimal("100")
        )
      }.to raise_error(Foaf::Trustline::Protocol::InsufficientCapacity)
    end

    it "raises on non-positive value" do
      expect {
        bm.apply_direct_transfer(
          balance: BigDecimal("0"),
          value: BigDecimal("0"),
          creditline_received: BigDecimal("100")
        )
      }.to raise_error(ArgumentError)
    end

    it "allows larger transfer when receiver owes sender" do
      # balance=50 means receiver owes sender 50, so capacity = 100 + 50 = 150
      result = bm.apply_direct_transfer(
        balance: BigDecimal("50"),
        value: BigDecimal("150"),
        creditline_received: BigDecimal("100")
      )
      expect(result).to eq(BigDecimal("-100"))
    end
  end

  describe ".capacity" do
    it "returns creditline when balance is zero" do
      expect(bm.capacity(balance: BigDecimal("0"), creditline_received: BigDecimal("100")))
        .to eq(BigDecimal("100"))
    end

    it "increases capacity when receiver owes sender" do
      expect(bm.capacity(balance: BigDecimal("30"), creditline_received: BigDecimal("100")))
        .to eq(BigDecimal("130"))
    end

    it "decreases capacity when sender owes receiver" do
      expect(bm.capacity(balance: BigDecimal("-40"), creditline_received: BigDecimal("100")))
        .to eq(BigDecimal("60"))
    end

    it "returns zero when fully at limit" do
      expect(bm.capacity(balance: BigDecimal("-100"), creditline_received: BigDecimal("100")))
        .to eq(BigDecimal("0"))
    end

    it "returns zero when over limit (should not happen, but safe)" do
      expect(bm.capacity(balance: BigDecimal("-150"), creditline_received: BigDecimal("100")))
        .to eq(BigDecimal("0"))
    end
  end

  describe ".balance_for_user" do
    it "returns balance as-is for user_a" do
      expect(bm.balance_for_user(balance: BigDecimal("25"), user_is_a: true))
        .to eq(BigDecimal("25"))
    end

    it "negates balance for user_b" do
      expect(bm.balance_for_user(balance: BigDecimal("25"), user_is_a: false))
        .to eq(BigDecimal("-25"))
    end
  end

  describe ".creditline_received_for_user" do
    it "returns b_to_a for user_a" do
      expect(bm.creditline_received_for_user(
        creditline_a_to_b: BigDecimal("100"),
        creditline_b_to_a: BigDecimal("50"),
        user_is_a: true
      )).to eq(BigDecimal("50"))
    end

    it "returns a_to_b for user_b" do
      expect(bm.creditline_received_for_user(
        creditline_a_to_b: BigDecimal("100"),
        creditline_b_to_a: BigDecimal("50"),
        user_is_a: false
      )).to eq(BigDecimal("100"))
    end
  end

  describe ".validate_transfer" do
    it "returns valid for transfer within capacity" do
      result = bm.validate_transfer(
        balance: BigDecimal("0"),
        value: BigDecimal("50"),
        creditline_received: BigDecimal("100")
      )
      expect(result[:valid]).to be true
    end

    it "returns invalid for transfer exceeding capacity" do
      result = bm.validate_transfer(
        balance: BigDecimal("0"),
        value: BigDecimal("150"),
        creditline_received: BigDecimal("100")
      )
      expect(result[:valid]).to be false
      expect(result[:available]).to eq(BigDecimal("100"))
    end

    it "returns invalid for non-positive value" do
      result = bm.validate_transfer(
        balance: BigDecimal("0"),
        value: BigDecimal("-1"),
        creditline_received: BigDecimal("100")
      )
      expect(result[:valid]).to be false
    end
  end
end
