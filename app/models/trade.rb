class Trade < ApplicationRecord
  belongs_to :trading_position
  
  validates :type, presence: true, inclusion: { in: %w[entry exit] }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending executed failed] }
  validates :binance_order_id, uniqueness: true, allow_nil: true

  before_save :calculate_profit_percentage, if: :will_save_change_to_price?

  scope :executed, -> { where(status: 'executed') }
  scope :pending, -> { where(status: 'pending') }
  scope :failed, -> { where(status: 'failed') }
  scope :entries, -> { where(type: 'entry') }
  scope :exits, -> { where(type: 'exit') }

  def profit_amount
    (price * quantity) - (trading_position.entry_price * quantity)
  end

  private

  def calculate_profit_percentage
    return unless type == 'exit' && trading_position.present?

    entry_trade = trading_position.trades.entries.executed.first
    return unless entry_trade

    self.profit_percentage = ((price - entry_trade.price) / entry_trade.price * 100).round(2)
  end
end 