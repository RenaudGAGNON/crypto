class ListingHistory < ApplicationRecord
  validates :symbol, presence: true, uniqueness: true
  validates :first_seen_at, presence: true

  scope :active, -> { where(is_active: true) }
  scope :recent, -> { where("first_seen_at >= ?", 1.week.ago) }

  def self.mark_as_inactive(symbol)
    find_by(symbol: symbol)&.update(is_active: false, last_seen_at: Time.current)
  end

  def self.update_last_seen(symbol)
    find_by(symbol: symbol)&.update(last_seen_at: Time.current)
  end
end
