class MigrateTradesData < ActiveRecord::Migration[7.1]
  def up
    # Supprimer les anciennes données si elles existent
    execute <<-SQL
      DELETE FROM trades 
      WHERE trading_config_id IS NOT NULL;
    SQL

    # Supprimer l'ancienne colonne
    remove_reference :trades, :trading_config, foreign_key: true
  end

  def down
    # Ajouter la référence à trading_config
    add_reference :trades, :trading_config, foreign_key: true
  end
end 