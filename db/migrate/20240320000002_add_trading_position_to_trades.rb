class AddTradingPositionToTrades < ActiveRecord::Migration[7.1]
  def change
    add_reference :trades, :trading_position, null: false, foreign_key: true
  end
end 