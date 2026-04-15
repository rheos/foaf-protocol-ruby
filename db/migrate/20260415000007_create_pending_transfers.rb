# Bilateral payment confirmation — FOAF's deliberate divergence from Trustlines.
# Trustlines transfers are sender-unilateral. FOAF requires receiver confirmation
# to prevent unwanted credit pushes (fits cooperative norms).
#
# Flow: sender creates → receiver confirms/rejects/counters → balance updates on confirm.

class CreatePendingTransfers < ActiveRecord::Migration[7.1]
  def change
    create_table :pending_transfers do |t|
      t.references :currency_network, null: false, foreign_key: true
      t.string :from_address, null: false, limit: 42
      t.string :to_address, null: false, limit: 42
      t.decimal :value, precision: 20, scale: 2, null: false
      t.decimal :max_fee, precision: 20, scale: 2, null: false, default: 0
      t.string :fee_payer, null: false, default: "sender", limit: 10  # "sender" or "receiver"
      t.json :path                                    # pre-calculated path (if multi-hop)
      t.text :extra_data                              # app-specific metadata
      t.string :status, null: false, default: "pending"  # pending, confirmed, rejected, cancelled
      t.text :rejected_reason
      t.datetime :confirmed_at
      t.datetime :resolved_at

      # === SIGNATURE (sender signs the transfer request) ===
      t.bigint :nonce
      t.text :signature

      t.timestamps

      t.index :status
      t.index :from_address
      t.index :to_address
    end
  end
end
