class CreateTradingMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :trading_metrics do |t|
      t.references :trading_config, null: false, foreign_key: true
      t.decimal :total_profit_loss, default: 0.0
      t.integer :total_trades, default: 0
      t.integer :completed_trades, default: 0
      t.decimal :win_rate, default: 0.0
      t.jsonb :daily_metrics, default: {}
      t.jsonb :symbol_metrics, default: {}

      t.timestamps
    end
  end
end 