class TradingRecommendation < ApplicationRecord
  validates :symbol, presence: true
  validates :action, presence: true, inclusion: { in: %w[buy sell hold] }
  validates :confidence, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :timestamp, presence: true

  def self.recent
    where('timestamp >= ?', 24.hours.ago)
  end

  def self.for_symbol(symbol)
    where(symbol: symbol)
  end

  def self.buy_signals
    where(action: 'buy')
  end

  def self.sell_signals
    where(action: 'sell')
  end

  def self.hold_signals
    where(action: 'hold')
  end

  def self.latest_for_symbol(symbol)
    for_symbol(symbol).order(timestamp: :desc).first
  end

  def self.average_confidence_for_symbol(symbol)
    where(symbol: symbol).average(:confidence)
  end

  def self.recent_buy_signals
    recent.buy_signals
  end

  def self.recent_sell_signals
    recent.sell_signals
  end

  def self.recent_hold_signals
    recent.hold_signals
  end

  def self.high_confidence_signals(min_confidence = 0.7)
    where('confidence >= ?', min_confidence)
  end

  def to_s
    "#{symbol} - #{action} (#{(confidence * 100).round}%)"
  end
end
