class CreateTradingPositions < ActiveRecord::Migration[7.1]
  def change
    create_table :trading_positions do |t|
      t.references :trading_config, null: false, foreign_key: true
      t.string :symbol, null: false
      t.decimal :entry_price, precision: 20, scale: 8, null: false
      t.decimal :quantity, precision: 20, scale: 8, null: false
      t.string :status, default: 'open', null: false
      t.datetime :entry_time, null: false
      t.decimal :stop_loss, precision: 20, scale: 8, null: false
      t.jsonb :take_profit_levels, default: [], null: false
      t.boolean :dry_run, default: false, null: false

      t.timestamps
    end

    add_index :trading_positions, :symbol
    add_index :trading_positions, :status
    add_index :trading_positions, :dry_run
  end
end 