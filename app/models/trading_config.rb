class TradingConfig < ApplicationRecord
  belongs_to :user

  validates :api_key, presence: true
  validates :api_secret, presence: true
  validates :mode, presence: true
  validates :check_interval, presence: true, numericality: { greater_than: 0 }
  validates :min_growth_rate, presence: true, numericality: { greater_than: 0 }
  validates :volume_spike_multiplier, presence: true, numericality: { greater_than: 1.0 }
  validates :rsi_threshold, presence: true, numericality: { greater_than: 0, less_than: 100 }
  validates :upper_wick_percentage, presence: true, numericality: { greater_than: 0, less_than: 100 }

  encrypts :api_key, :api_secret

  has_many :trades, dependent: :destroy
  has_many :trading_metrics

  enum :mode, { simulation: 0, live: 1 }
  enum :status, { inactive: 0, active: 1, paused: 2 }

  after_save :update_analysis_status

  # Constantes pour les indicateurs techniques
  INDICATORS = {
    volume_spike_multiplier: 2.5,
    rsi_threshold: 65.0,
    upper_wick_percentage: 2.0,
    vwap_period: 20,
    ema_fast: 5,
    ema_slow: 20,
    macd_fast: 12,
    macd_slow: 26,
    macd_signal: 9
  }.freeze

  def live_mode?
    mode == "live"
  end

  def start_trading
    update(status: :active)
  end

  def stop_trading
    update(status: :inactive)
  end

  def check_buy_conditions(indicators)
    # Volume spike (x2.5 la moyenne)
    volume_spike = indicators[:volume] > (indicators[:volume_ma] * volume_spike_multiplier)

    # Prix au-dessus du VWAP
    above_vwap = indicators[:current_price] > indicators[:vwap]

    # RSI > seuil configuré
    strong_rsi = indicators[:rsi] > rsi_threshold

    # EMA5 > EMA20 (croisement haussier)
    bullish_ema = indicators[:ema5] > indicators[:ema20]

    # MACD croisement haussier
    bullish_macd = indicators[:macd][:signal] > indicators[:macd][:histogram]

    # Pas de mèche haute importante (moins de X% de la bougie)
    no_upper_wick = (indicators[:high] - [ indicators[:open], indicators[:close] ].max) < (indicators[:high] * (upper_wick_percentage / 100.0))

    volume_spike && above_vwap && strong_rsi && bullish_ema && bullish_macd && no_upper_wick
  end

  private

  def update_analysis_status
    if status_changed? && active?
      # Démarrer l'analyse immédiatement
      TradingAnalysisJob.perform_async(id)
      Rails.logger.info "Démarrage de l'analyse pour la configuration #{id}"
    elsif status_changed? && (inactive? || paused?)
      Rails.logger.info "Arrêt de l'analyse pour la configuration #{id}"
    end
  end
end
