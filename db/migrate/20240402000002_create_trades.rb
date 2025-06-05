class CreateTrades < ActiveRecord::Migration[7.1]
  def change
    create_table :trades do |t|
      t.references :trading_position, null: false, foreign_key: true
      t.string :type, null: false  # 'entry' ou 'exit'
      t.decimal :price, precision: 20, scale: 8, null: false
      t.decimal :quantity, precision: 20, scale: 8, null: false
      t.decimal :profit_percentage, precision: 10, scale: 2
      t.string :status, default: 'pending'  # 'pending', 'executed', 'failed'
      t.string :binance_order_id
      t.datetime :executed_at
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :trades, :type
    add_index :trades, :status
    add_index :trades, :binance_order_id, unique: true
  end
end 