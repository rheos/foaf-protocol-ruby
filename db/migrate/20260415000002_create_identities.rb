# An identity in FOAF is a public key, just like on a blockchain.
# FOAF never stores private keys — the consuming app is the custodial wallet.
# The address is derived from the public key (secp256k1, Ethereum-compatible).

class CreateIdentities < ActiveRecord::Migration[7.1]
  def change
    create_table :identities do |t|
      # === CRYPTOGRAPHIC IDENTITY ===
      t.string :address, null: false, limit: 42       # derived from public key (0x-prefixed hex)
      t.text :public_key, null: false                  # full secp256k1 public key (hex)

      t.timestamps

      t.index :address, unique: true
    end
  end
end
