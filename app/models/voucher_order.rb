class VoucherOrder < ApplicationRecord
  validates :symbol, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending executed failed] }
  validates :order_id, uniqueness: true, allow_nil: true

  scope :executed, -> { where(status: "executed") }
  scope :pending, -> { where(status: "pending") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(created_at: :desc) }

  def total_value
    amount * price
  end

  def profit_percentage
    return 0 unless profit_loss && total_value > 0
    (profit_loss / total_value * 100).round(2)
  end
end
