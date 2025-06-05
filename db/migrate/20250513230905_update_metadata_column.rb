class UpdateMetadataColumn < ActiveRecord::Migration[7.2]
  def change
    change_column :trading_recommendations, :metadata, :jsonb, using: 'metadata::jsonb', default: {}
  end
end 