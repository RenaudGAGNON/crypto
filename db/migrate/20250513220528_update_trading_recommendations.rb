class UpdateTradingRecommendations < ActiveRecord::Migration[7.0]
  def change
    # Renommer la colonne 'recommendation' en 'action' si elle existe
    if column_exists?(:trading_recommendations, :recommendation)
      rename_column :trading_recommendations, :recommendation, :action
    end

    # Ajouter les colonnes manquantes si elles n'existent pas
    unless column_exists?(:trading_recommendations, :confidence)
      add_column :trading_recommendations, :confidence, :decimal, precision: 8, scale: 4, null: false, default: 0.5
    end

    unless column_exists?(:trading_recommendations, :price)
      add_column :trading_recommendations, :price, :decimal, precision: 20, scale: 8, null: false
    end

    unless column_exists?(:trading_recommendations, :timestamp)
      add_column :trading_recommendations, :timestamp, :datetime, null: false
    end

    unless column_exists?(:trading_recommendations, :metadata)
      add_column :trading_recommendations, :metadata, :jsonb, default: {}
    end

    # Ajouter les index s'ils n'existent pas
    unless index_exists?(:trading_recommendations, :symbol)
      add_index :trading_recommendations, :symbol
    end

    unless index_exists?(:trading_recommendations, :timestamp)
      add_index :trading_recommendations, :timestamp
    end

    unless index_exists?(:trading_recommendations, [:symbol, :timestamp])
      add_index :trading_recommendations, [:symbol, :timestamp]
    end
  end
end 