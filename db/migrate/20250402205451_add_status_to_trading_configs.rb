class AddStatusToTradingConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :trading_configs, :status, :integer, default: 0, null: false
  end
end 