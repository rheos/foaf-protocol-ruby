# Pending trustline update requests — the first stage of the two-stage accept pattern.
# Mirrors CurrencyNetworkBasic TrustlineRequest struct.
#
# When a user requests credit limit increases, a request is created.
# The counterparty can accept (matching or more conservative terms) or it expires.
# Reductions are applied immediately without a request.

class CreateTrustlineUpdateRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :trustline_update_requests do |t|
      t.references :trustline, null: false, foreign_key: true

      # === PROPOSED TERMS (from initiator's perspective) ===
      t.decimal :creditline_given, precision: 20, scale: 2, null: false
      t.decimal :creditline_received, precision: 20, scale: 2, null: false
      t.integer :interest_rate_given, null: false, default: 0
      t.integer :interest_rate_received, null: false, default: 0
      t.boolean :is_frozen, null: false, default: false

      # === WHO INITIATED ===
      t.string :initiator_address, null: false, limit: 42

      t.timestamps

      # One pending request per trustline
      t.index :trustline_id, unique: true
    end
  end
end
