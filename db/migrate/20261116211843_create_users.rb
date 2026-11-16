# frozen_string_literal: true

# Accounts: one per email (enforced by a unique index), bcrypt hash only.
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
