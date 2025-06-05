class FixTakeProfitLevelsColumn < ActiveRecord::Migration[7.1]
  def up
    # Sauvegarder les données existantes
    execute <<-SQL
      CREATE TABLE trading_positions_backup AS 
      SELECT * FROM trading_positions;
    SQL

    # Supprimer la contrainte de clé étrangère temporairement
    remove_foreign_key :trades, :trading_positions if foreign_key_exists?(:trades, :trading_positions)

    # Modifier la colonne
    change_column :trading_positions, :take_profit_levels, :jsonb, using: 'take_profit_levels::jsonb', default: [], null: false

    # Restaurer les données
    execute <<-SQL
      UPDATE trading_positions p
      SET take_profit_levels = b.take_profit_levels::jsonb
      FROM trading_positions_backup b
      WHERE p.id = b.id;
    SQL

    # Supprimer la table de backup
    drop_table :trading_positions_backup

    # Restaurer la contrainte de clé étrangère
    add_foreign_key :trades, :trading_positions if foreign_key_exists?(:trades, :trading_positions)
  end

  def down
    # Sauvegarder les données existantes
    execute <<-SQL
      CREATE TABLE trading_positions_backup AS 
      SELECT * FROM trading_positions;
    SQL

    # Supprimer la contrainte de clé étrangère temporairement
    remove_foreign_key :trades, :trading_positions if foreign_key_exists?(:trades, :trading_positions)

    # Revenir au type json
    change_column :trading_positions, :take_profit_levels, :json, using: 'take_profit_levels::json', default: [], null: false

    # Restaurer les données
    execute <<-SQL
      UPDATE trading_positions p
      SET take_profit_levels = b.take_profit_levels::json
      FROM trading_positions_backup b
      WHERE p.id = b.id;
    SQL

    # Supprimer la table de backup
    drop_table :trading_positions_backup

    # Restaurer la contrainte de clé étrangère
    add_foreign_key :trades, :trading_positions if foreign_key_exists?(:trades, :trading_positions)
  end
end 