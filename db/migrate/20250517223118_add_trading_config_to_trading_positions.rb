class AddTradingConfigToTradingPositions < ActiveRecord::Migration[7.2]
  def change
    add_reference :trading_positions, :trading_config, null: false, foreign_key: true
  end
end
