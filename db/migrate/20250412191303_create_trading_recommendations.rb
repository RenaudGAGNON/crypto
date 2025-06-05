class CreateTradingRecommendations < ActiveRecord::Migration[7.2]
  def change
    create_table :trading_recommendations do |t|
      t.string :symbol
      t.string :recommendation
      t.float :confidence
      t.decimal :price
      t.datetime :timestamp

      t.timestamps
    end
  end
end
