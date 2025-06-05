class TradingConfigsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trading_config, only: [ :show, :edit, :update, :destroy, :start_trading, :stop_trading ]

  def index
    @trading_configs = current_user.trading_configs
    if @trading_configs.any?
      @trading_config = @trading_configs.first
      @trades = @trading_config.trades.order(created_at: :desc)
      @metrics = calculate_trading_metrics
      @opportunities = fetch_current_opportunities
    end
  end

  def show
  end

  def new
    @trading_config = current_user.trading_configs.build
  end

  def edit
  end

  def create
    @trading_config = current_user.trading_configs.build(trading_config_params)

    if @trading_config.save
      redirect_to @trading_config, notice: "Configuration cr\u00E9\u00E9e avec succ\u00E8s."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @trading_config.update(trading_config_params)
      redirect_to @trading_config, notice: "Configuration mise \u00E0 jour avec succ\u00E8s."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @trading_config.destroy
    redirect_to trading_configs_url, notice: "Configuration supprim\u00E9e avec succ\u00E8s."
  end

  def start_trading
    @trading_config.start_trading
    redirect_to @trading_config, notice: "Trading d\u00E9marr\u00E9 avec succ\u00E8s."
  end

  def stop_trading
    @trading_config.stop_trading
    redirect_to @trading_config, notice: "Trading arr\u00EAt\u00E9 avec succ\u00E8s."
  end

  private

  def set_trading_config
    @trading_config = current_user.trading_configs.find(params[:id])
  end

  def trading_config_params
    params.require(:trading_config).permit(
      :api_key, :api_secret, :mode, :check_interval, :min_growth_rate
    )
  end

  def calculate_trading_metrics
    return {} unless @trading_config

    {
      total_trades: @trading_config.trades.count,
      completed_trades: @trading_config.trades.completed.count,
      total_profit_loss: @trading_config.trades.completed.sum(&:profit_loss),
      win_rate: calculate_win_rate
    }
  end

  def calculate_win_rate
    completed_trades = @trading_config.trades.completed
    return 0 if completed_trades.empty?

    profitable_trades = completed_trades.select { |t| t.profit_loss > 0 }
    (profitable_trades.size.to_f / completed_trades.size) * 100
  end

  def fetch_current_opportunities
    return [] unless @trading_config

    service = BinanceTradingService.new(@trading_config)
    service.analyze_new_listings
  end
end
