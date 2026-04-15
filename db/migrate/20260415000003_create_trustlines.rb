# Bilateral credit line between two identities within a currency network.
# Mirrors CurrencyNetworkBasic TrustlineAgreement + TrustlineBalances structs.
#
# Canonical ordering: user_a_address < user_b_address (prevents duplicates).
# Balance convention: positive = B owes A, negative = A owes B.
# "given" = what user_a extends to user_b. "received" = what user_b extends to user_a.

class CreateTrustlines < ActiveRecord::Migration[7.1]
  def change
    create_table :trustlines do |t|
      # === NETWORK + USER PAIR ===
      t.references :currency_network, null: false, foreign_key: true
      t.string :user_a_address, null: false, limit: 42
      t.string :user_b_address, null: false, limit: 42

      # === CREDIT LIMITS (TrustlineAgreement) ===
      t.decimal :creditline_given, precision: 20, scale: 2, null: false, default: 0
      t.decimal :creditline_received, precision: 20, scale: 2, null: false, default: 0

      # === INTEREST RATES (Phase 1: zero) ===
      t.integer :interest_rate_given, null: false, default: 0     # 0.01% per year
      t.integer :interest_rate_received, null: false, default: 0

      # === STATE ===
      t.boolean :is_frozen, null: false, default: false
      t.boolean :allow_routing, null: false, default: true  # FOAF addition: opt-out of being a routing hop

      # === BALANCE (TrustlineBalances — materialized cache) ===
      t.decimal :balance, precision: 20, scale: 2, null: false, default: 0
      t.integer :balance_mtime, null: false, default: 0  # unix timestamp, last interest application

      t.timestamps

      # One trustline per user pair per network
      t.index [:currency_network_id, :user_a_address, :user_b_address],
              unique: true, name: "idx_trustlines_network_user_pair"
      t.index :user_a_address
      t.index :user_b_address
    end
  end
end
