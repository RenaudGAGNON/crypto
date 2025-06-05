class AddUserToTradingConfigs < ActiveRecord::Migration[7.2]
  def change
    # Ajouter la colonne user_id comme nullable
    add_reference :trading_configs, :user, null: true, foreign_key: true
    
    # Créer un utilisateur par défaut si nécessaire
    reversible do |dir|
      dir.up do
        # Créer un utilisateur par défaut
        default_user = User.create!(
          email: 'admin@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        )
        
        # Mettre à jour tous les enregistrements existants avec l'utilisateur par défaut
        ActiveRecord::Base.connection.execute("UPDATE trading_configs SET user_id = #{default_user.id} WHERE user_id IS NULL")
        
        # Rendre la colonne non nullable
        change_column_null :trading_configs, :user_id, false
      end
      
      dir.down do
        change_column_null :trading_configs, :user_id, true
        remove_reference :trading_configs, :user
      end
    end
  end
end
