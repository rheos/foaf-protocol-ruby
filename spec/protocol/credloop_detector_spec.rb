# frozen_string_literal: true

# Test vectors for credloop detection.
# Any future implementation (Rust, Scrypto) must pass the same cases.

require_relative "../../foaf_trustline/lib/foaf/trustline/protocol"

RSpec.describe Foaf::Trustline::Protocol::CredloopDetector do
  let(:cd) { described_class }

  describe ".find_loops" do
    it "finds a simple 3-node cycle" do
      edges = [
        { from: "A", to: "B", amount: BigDecimal("10") },
        { from: "B", to: "C", amount: BigDecimal("10") },
        { from: "C", to: "A", amount: BigDecimal("10") },
      ]

      loops = cd.find_loops(edges)
      expect(loops.size).to eq(1)
      expect(loops.first[:cancellable_amount]).to eq(BigDecimal("10"))
      expect(loops.first[:path].size).to eq(3)
    end

    it "cancellable amount is the minimum debt in the cycle" do
      edges = [
        { from: "A", to: "B", amount: BigDecimal("20") },
        { from: "B", to: "C", amount: BigDecimal("5") },
        { from: "C", to: "A", amount: BigDecimal("15") },
      ]

      loops = cd.find_loops(edges)
      expect(loops.size).to eq(1)
      expect(loops.first[:cancellable_amount]).to eq(BigDecimal("5"))
    end

    it "finds no loops when there are none" do
      edges = [
        { from: "A", to: "B", amount: BigDecimal("10") },
        { from: "B", to: "C", amount: BigDecimal("10") },
      ]

      loops = cd.find_loops(edges)
      expect(loops).to be_empty
    end

    it "finds no loops when all debts go one direction" do
      edges = [
        { from: "A", to: "B", amount: BigDecimal("10") },
        { from: "A", to: "C", amount: BigDecimal("10") },
      ]

      loops = cd.find_loops(edges)
      expect(loops).to be_empty
    end

    it "finds a 4-node cycle" do
      edges = [
        { from: "A", to: "B", amount: BigDecimal("10") },
        { from: "B", to: "C", amount: BigDecimal("10") },
        { from: "C", to: "D", amount: BigDecimal("10") },
        { from: "D", to: "A", amount: BigDecimal("10") },
      ]

      loops = cd.find_loops(edges)
      expect(loops.size).to eq(1)
      expect(loops.first[:path].size).to eq(4)
      expect(loops.first[:cancellable_amount]).to eq(BigDecimal("10"))
    end

    it "finds multiple independent cycles" do
      edges = [
        # Cycle 1: A → B → C → A
        { from: "A", to: "B", amount: BigDecimal("10") },
        { from: "B", to: "C", amount: BigDecimal("10") },
        { from: "C", to: "A", amount: BigDecimal("10") },
        # Cycle 2: D → E → F → D
        { from: "D", to: "E", amount: BigDecimal("5") },
        { from: "E", to: "F", amount: BigDecimal("5") },
        { from: "F", to: "D", amount: BigDecimal("5") },
      ]

      loops = cd.find_loops(edges)
      expect(loops.size).to eq(2)
    end

    it "ignores zero-amount edges" do
      edges = [
        { from: "A", to: "B", amount: BigDecimal("10") },
        { from: "B", to: "C", amount: BigDecimal("0") },
        { from: "C", to: "A", amount: BigDecimal("10") },
      ]

      loops = cd.find_loops(edges)
      expect(loops).to be_empty
    end

    it "respects max_length" do
      edges = [
        { from: "A", to: "B", amount: BigDecimal("10") },
        { from: "B", to: "C", amount: BigDecimal("10") },
        { from: "C", to: "D", amount: BigDecimal("10") },
        { from: "D", to: "A", amount: BigDecimal("10") },
      ]

      loops = cd.find_loops(edges, max_length: 3)
      expect(loops).to be_empty # 4-node cycle exceeds max_length of 3

      loops = cd.find_loops(edges, max_length: 4)
      expect(loops.size).to eq(1)
    end

    it "handles a network with overlapping cycles" do
      # A → B → C → A (cycle 1)
      # A → B → D → A (cycle 2)
      edges = [
        { from: "A", to: "B", amount: BigDecimal("10") },
        { from: "B", to: "C", amount: BigDecimal("10") },
        { from: "C", to: "A", amount: BigDecimal("10") },
        { from: "B", to: "D", amount: BigDecimal("5") },
        { from: "D", to: "A", amount: BigDecimal("5") },
      ]

      loops = cd.find_loops(edges)
      expect(loops.size).to eq(2)
    end
  end

  describe ".find_best_loop" do
    it "returns the loop with highest cancellable amount" do
      edges = [
        { from: "A", to: "B", amount: BigDecimal("10") },
        { from: "B", to: "C", amount: BigDecimal("10") },
        { from: "C", to: "A", amount: BigDecimal("10") },
        { from: "D", to: "E", amount: BigDecimal("50") },
        { from: "E", to: "F", amount: BigDecimal("50") },
        { from: "F", to: "D", amount: BigDecimal("50") },
      ]

      best = cd.find_best_loop(edges)
      expect(best[:cancellable_amount]).to eq(BigDecimal("50"))
    end

    it "returns nil when no loops exist" do
      edges = [{ from: "A", to: "B", amount: BigDecimal("10") }]
      expect(cd.find_best_loop(edges)).to be_nil
    end
  end

  describe ".build_transfer_path" do
    it "creates a reversed circular path (payments oppose debt direction)" do
      # Debt cycle: A→B→C→A. Payment path: A→C→B→A
      path = cd.build_transfer_path(["A", "B", "C"])
      expect(path).to eq(["A", "C", "B", "A"])
    end

    it "handles a 4-node cycle" do
      # Debt: A→B→C→D→A. Payment: A→D→C→B→A
      path = cd.build_transfer_path(["A", "B", "C", "D"])
      expect(path).to eq(["A", "D", "C", "B", "A"])
    end
  end

  describe ".cancellable_amount" do
    it "returns the minimum debt along the cycle" do
      path = ["A", "B", "C"]
      amounts = { ["A", "B"] => BigDecimal("20"), ["B", "C"] => BigDecimal("5"), ["C", "A"] => BigDecimal("15") }
      expect(cd.cancellable_amount(path, amounts)).to eq(BigDecimal("5"))
    end
  end
end
