# frozen_string_literal: true

# Bumped on sign-out. Sessions store the version they were created with, so a
# bump ends every existing session for that user, including copied cookies.
class AddSessionVersionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :session_version, :integer, null: false, default: 0
  end
end
