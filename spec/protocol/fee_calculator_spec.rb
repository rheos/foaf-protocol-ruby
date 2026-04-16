# frozen_string_literal: true

# Test vectors for fee calculation — must match CurrencyNetworkBasic._calculateFees
# Any future implementation (Rust, Scrypto) must pass the same cases.

require_relative "../../foaf_trustline/lib/foaf/trustline/protocol"

RSpec.describe Foaf::Trustline::Protocol::FeeCalculator do
  let(:fc) { described_class }

  describe ".calculate_fees" do
    it "returns zero when divisor is zero (fees disabled)" do
      expect(fc.calculate_fees(
        imbalance_generated: BigDecimal("100"),
        capacity_imbalance_fee_divisor: 0
      )).to eq(BigDecimal("0"))
    end

    it "returns zero when imbalance is zero" do
      expect(fc.calculate_fees(
        imbalance_generated: BigDecimal("0"),
        capacity_imbalance_fee_divisor: 100
      )).to eq(BigDecimal("0"))
    end

    it "calculates ceiling division (100 / 100 = 1)" do
      expect(fc.calculate_fees(
        imbalance_generated: BigDecimal("100"),
        capacity_imbalance_fee_divisor: 100
      )).to eq(BigDecimal("1"))
    end

    it "rounds up (101 / 100 = 2)" do
      expect(fc.calculate_fees(
        imbalance_generated: BigDecimal("101"),
        capacity_imbalance_fee_divisor: 100
      )).to eq(BigDecimal("2"))
    end

    it "calculates 1 / 100 = 1 (minimum fee)" do
      expect(fc.calculate_fees(
        imbalance_generated: BigDecimal("1"),
        capacity_imbalance_fee_divisor: 100
      )).to eq(BigDecimal("1"))
    end

    it "calculates 200 / 100 = 2" do
      expect(fc.calculate_fees(
        imbalance_generated: BigDecimal("200"),
        capacity_imbalance_fee_divisor: 100
      )).to eq(BigDecimal("2"))
    end
  end

  describe ".calculate_fees_reverse" do
    it "returns zero when divisor is zero" do
      expect(fc.calculate_fees_reverse(
        imbalance_generated: BigDecimal("100"),
        capacity_imbalance_fee_divisor: 0
      )).to eq(BigDecimal("0"))
    end

    it "uses divisor-1 for reverse (100 / 99 = 2)" do
      expect(fc.calculate_fees_reverse(
        imbalance_generated: BigDecimal("100"),
        capacity_imbalance_fee_divisor: 100
      )).to eq(BigDecimal("2"))
    end

    it "calculates 99 / 99 = 1" do
      expect(fc.calculate_fees_reverse(
        imbalance_generated: BigDecimal("99"),
        capacity_imbalance_fee_divisor: 100
      )).to eq(BigDecimal("1"))
    end
  end

  describe ".imbalance_generated" do
    it "returns full value when balance is zero" do
      expect(fc.imbalance_generated(
        value: BigDecimal("100"),
        balance: BigDecimal("0")
      )).to eq(BigDecimal("100"))
    end

    it "returns full value when sender already owes (negative balance)" do
      expect(fc.imbalance_generated(
        value: BigDecimal("100"),
        balance: BigDecimal("-50")
      )).to eq(BigDecimal("100"))
    end

    it "subtracts existing positive balance (debt reduces imbalance)" do
      expect(fc.imbalance_generated(
        value: BigDecimal("100"),
        balance: BigDecimal("30")
      )).to eq(BigDecimal("70"))
    end

    it "returns zero when transfer is within existing debt" do
      expect(fc.imbalance_generated(
        value: BigDecimal("50"),
        balance: BigDecimal("100")
      )).to eq(BigDecimal("0"))
    end

    it "returns zero when transfer exactly matches debt" do
      expect(fc.imbalance_generated(
        value: BigDecimal("100"),
        balance: BigDecimal("100")
      )).to eq(BigDecimal("0"))
    end
  end
end
