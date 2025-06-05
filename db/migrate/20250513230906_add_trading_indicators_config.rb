class AddTradingIndicatorsConfig < ActiveRecord::Migration[7.2]
  def change
    add_column :trading_configs, :volume_spike_multiplier, :decimal, precision: 5, scale: 2, default: 2.5
    add_column :trading_configs, :rsi_threshold, :decimal, precision: 5, scale: 2, default: 65.0
    add_column :trading_configs, :upper_wick_percentage, :decimal, precision: 5, scale: 2, default: 2.0
  end
end 