class TradingPosition < ApplicationRecord
  belongs_to :trading_config
  has_many :trades, dependent: :destroy

  validates :symbol, presence: true, uniqueness: true
  validates :entry_price, presence: true, numericality: { greater_than: 0 }
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[open closed] }
  validates :entry_time, presence: true
  validates :take_profit_levels, presence: true
  validates :stop_loss, presence: true, numericality: { greater_than: 0 }
  validate :validate_take_profit_levels

  before_validation :set_default_values

  def total_profit_percentage
    return 0 if trades.empty?

    trades.sum(&:profit_percentage)
  end

  def current_profit_percentage(current_price)
    return 0 if status == "closed"

    ((current_price - entry_price) / entry_price * 100).round(2)
  end

  def update_status
    return if status == "closed"

    if trades.any? { |trade| trade.type == "exit" && trade.status == "executed" }
      update(status: "closed")
    end
  end

  private

  def set_default_values
    self.status ||= "open"
    self.entry_time ||= Time.current
    self.take_profit_levels ||= [
      { price: entry_price * 1.10, percentage: 10, status: "pending" },
      { price: entry_price * 1.25, percentage: 25, status: "pending" },
      { price: entry_price * 1.50, percentage: 50, status: "pending" }
    ]
  end

  def validate_take_profit_levels
    return if take_profit_levels.blank?

    unless take_profit_levels.is_a?(Array)
      errors.add(:take_profit_levels, "doit être un tableau")
      return
    end

    take_profit_levels.each_with_index do |level, index|
      unless level.is_a?(Hash) && level["percentage"].present? && level["price"].present?
        errors.add(:take_profit_levels, "le niveau #{index + 1} doit contenir un pourcentage et un prix")
      end

      if level["percentage"].present? && !level["percentage"].is_a?(Numeric)
        errors.add(:take_profit_levels, "le pourcentage du niveau #{index + 1} doit être un nombre")
      end

      if level["price"].present? && !level["price"].is_a?(Numeric)
        errors.add(:take_profit_levels, "le prix du niveau #{index + 1} doit être un nombre")
      end
    end
  end
end
