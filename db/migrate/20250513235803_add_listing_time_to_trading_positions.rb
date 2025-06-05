class AddListingTimeToTradingPositions < ActiveRecord::Migration[7.2]
  def change
    add_column :trading_positions, :listing_time, :datetime
    add_index :trading_positions, :listing_time
  end
end 