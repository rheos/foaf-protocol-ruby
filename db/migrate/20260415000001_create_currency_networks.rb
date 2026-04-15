# Mirrors CurrencyNetworkBasic.sol init() parameters.
# A currency network is a named, denominated credit ledger.
# Each network is an independent system — its own trustlines, denomination, fee params.
# Think of it as a Scrypto component instance.

class CreateCurrencyNetworks < ActiveRecord::Migration[7.1]
  def change
    create_table :currency_networks do |t|
      # === IDENTITY ===
      t.string :address, null: false, limit: 42  # unique network identifier (hex address format)
      t.string :name, null: false                 # e.g. "Growoperative Gardens (CAD)"
      t.string :symbol, null: false               # e.g. "GGRO"

      # === DENOMINATION ===
      t.integer :decimals, null: false, default: 2  # decimal precision

      # === FEE PARAMETERS ===
      # 0 = fees disabled (Phase 1). Non-zero activates capacity imbalance fees.
      # Mirrors CurrencyNetworkBasic.capacityImbalanceFeeDivisor
      t.integer :capacity_imbalance_fee_divisor, null: false, default: 0

      # === INTEREST PARAMETERS (Phase 1: all zero) ===
      t.integer :default_interest_rate, null: false, default: 0  # in 0.01% per year
      t.boolean :custom_interests, null: false, default: false
      t.boolean :prevent_mediator_interests, null: false, default: false

      # === NETWORK SETTINGS ===
      t.integer :max_hops, null: false, default: 5   # max path length for multi-hop
      t.boolean :is_frozen, null: false, default: false
      t.string :owner_address, limit: 42              # identity that created this network

      t.timestamps

      t.index :address, unique: true
      t.index :symbol, unique: true
    end
  end
end
