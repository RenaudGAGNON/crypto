class CreateTradingConfigs < ActiveRecord::Migration[7.2]
  def change
    create_table :trading_configs do |t|
      t.string :api_key, null: false
      t.string :api_secret, null: false
      t.string :mode, null: false, default: 'dry_run'
      t.integer :check_interval, null: false, default: 300
      t.decimal :min_growth_rate, null: false, default: 5.0
      t.decimal :max_investment_per_trade, null: false, default: 100.0
      t.boolean :active, default: false

      t.timestamps
    end
  end
end 