# db/migrate/001_create_links.rb
class CreateLinks < ActiveRecord::Migration[7.0]
  def change
    create_table :links do |t|
      t.string :short_code, null: false
      t.string :long_url, null: false
      t.integer :click_count, null: false, default: 0
      t.timestamps
    end

    add_index :links, :short_code, unique: true
  end
end
