class CreateListingHistories < ActiveRecord::Migration[7.0]
  def change
    create_table :listing_histories do |t|
      t.string :symbol, null: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :listing_histories, :symbol, unique: true
    add_index :listing_histories, :first_seen_at
    add_index :listing_histories, :is_active
  end
end
