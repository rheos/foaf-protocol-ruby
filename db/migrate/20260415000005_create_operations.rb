# Event-sourced operations log — the source of truth for all protocol state changes.
# Cross-cutting: every module's state changes flow through this table.
#
# Materialized state (trustline balances, etc.) is a cache derived from replaying
# operations in order. A nightly invariant check verifies consistency.
#
# Signature columns exist from day one (nullable Phase 1).
# When signatures activate, this table becomes the audit-grade proof chain.

class CreateOperations < ActiveRecord::Migration[7.1]
  def change
    create_table :operations do |t|
      # === OPERATION IDENTITY ===
      t.string :operation_type, null: false       # e.g. "transfer", "trustline_update", "trustline_update_accept"
      t.string :module_name, null: false           # "trustline", "supply_chain", etc.
      t.references :currency_network, null: true, foreign_key: true

      # === ACTOR ===
      t.string :actor_address, null: false, limit: 42

      # === PAYLOAD ===
      t.json :inputs, null: false                  # operation-specific input data

      # === SIGNATURE (nullable Phase 1) ===
      t.bigint :nonce                              # monotonic per identity
      t.text :signature                            # secp256k1 signature of operation payload

      # === IDEMPOTENCY ===
      t.string :idempotency_key, limit: 64

      # === MULTI-HOP GROUPING ===
      t.string :multi_hop_id, limit: 36            # UUID grouping hops of an atomic transfer
      t.bigint :parent_operation_id                 # for operations that trigger sub-operations

      # === FEES (zero in Phase 1) ===
      t.decimal :fee_amount, precision: 20, scale: 2, default: 0
      t.string :fee_currency, limit: 10
      t.json :fee_distribution                     # breakdown when fees activate

      # === RESULT ===
      t.string :status, null: false, default: "applied"  # applied, failed, pending

      t.timestamps

      t.index :operation_type
      t.index :actor_address
      t.index :multi_hop_id
      t.index :idempotency_key, unique: true
      t.index :parent_operation_id
      t.index [:currency_network_id, :created_at], name: "idx_ops_network_time"
    end
  end
end
