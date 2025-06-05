class CreateVoucherOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :voucher_orders do |t|
      t.string :symbol, null: false
      t.decimal :amount, precision: 20, scale: 8, null: false
      t.decimal :price, precision: 20, scale: 8, null: false
      t.string :status, default: 'pending', null: false
      t.string :order_id
      t.decimal :profit_loss, default: 0.0
      t.jsonb :metadata, default: {}
      t.datetime :executed_at

      t.timestamps
    end

    add_index :voucher_orders, :symbol
    add_index :voucher_orders, :status
    add_index :voucher_orders, :order_id, unique: true
  end
end
