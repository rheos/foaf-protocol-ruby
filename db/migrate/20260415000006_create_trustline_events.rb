# Trustline events — append-only log mirroring blockchain events.
# Maps to Trustlines' Transfer, TrustlineUpdate, BalanceUpdate, etc.
#
# Each event references the operation that produced it.
# This is what the events API returns and what WebSocket streams push.
# Never mutated — reversals create new events.

class CreateTrustlineEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :trustline_events do |t|
      # === EVENT IDENTITY ===
      t.references :operation, null: false, foreign_key: true
      t.references :currency_network, null: false, foreign_key: true
      t.string :event_type, null: false  # Transfer, TrustlineUpdate, TrustlineUpdateRequest,
                                         # TrustlineUpdateCancel, BalanceUpdate

      # === PARTICIPANTS ===
      t.string :from_address, null: false, limit: 42
      t.string :to_address, null: false, limit: 42

      # === EVENT DATA ===
      # Transfer events
      t.decimal :value, precision: 20, scale: 2          # amount transferred
      t.text :extra_data                                  # app-specific metadata (JSON)

      # TrustlineUpdate events
      t.decimal :creditline_given, precision: 20, scale: 2
      t.decimal :creditline_received, precision: 20, scale: 2
      t.integer :interest_rate_given
      t.integer :interest_rate_received
      t.boolean :is_frozen

      # BalanceUpdate events
      t.decimal :balance, precision: 20, scale: 2

      # Transfer path info
      t.json :path                                        # full address path for multi-hop
      t.string :fee_payer, limit: 10                      # "sender" or "receiver"
      t.decimal :total_fees, precision: 20, scale: 2
      t.json :fees_paid                                   # per-hop fee breakdown

      t.timestamps

      t.index :event_type
      t.index :from_address
      t.index :to_address
      t.index [:currency_network_id, :event_type, :created_at], name: "idx_events_network_type_time"
      t.index [:from_address, :event_type], name: "idx_events_from_type"
      t.index [:to_address, :event_type], name: "idx_events_to_type"
    end
  end
end
