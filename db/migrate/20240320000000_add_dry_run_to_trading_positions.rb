class AddDryRunToTradingPositions < ActiveRecord::Migration[7.1]
  def change
    add_column :trading_positions, :dry_run, :boolean, default: false
    add_index :trading_positions, :dry_run
  end
end 