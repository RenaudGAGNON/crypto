class CreateGrowthOpportunities < ActiveRecord::Migration[7.2]
  def change
    create_table :growth_opportunities do |t|
      t.string :symbol
      t.decimal :price
      t.decimal :volume_24h
      t.decimal :price_change_24h
      t.decimal :market_cap

      t.timestamps
    end
  end
end
