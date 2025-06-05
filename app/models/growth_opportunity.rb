class GrowthOpportunity < ApplicationRecord
  validates :symbol, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :volume_24h, presence: true, numericality: { greater_than: 0 }
  validates :price_change_24h, presence: true
  validates :market_cap, presence: true, numericality: { greater_than: 0 }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :high_growth, -> { where('price_change_24h > ?', 5) } # Plus de 5% de croissance
end 