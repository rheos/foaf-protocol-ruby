# DAO-governable protocol parameters.
# Phase 1: all values set to zero/default by seed data.
# Activation = changing a parameter value, not deploying new code.

class CreateProtocolParameters < ActiveRecord::Migration[7.1]
  def change
    create_table :protocol_parameters do |t|
      t.string :key, null: false
      t.string :value, null: false
      t.string :description

      t.timestamps

      t.index :key, unique: true
    end
  end
end
