# Identities table was unnecessary scaffolding.
# Addresses are just strings on trustlines — identity is proven by signature
# on every request, not by a stored record. Same as blockchain.

class DropIdentities < ActiveRecord::Migration[7.1]
  def change
    drop_table :identities
  end
end
