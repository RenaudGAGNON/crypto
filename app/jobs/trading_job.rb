class TradingJob
  include Sidekiq::Job
  
  def perform(trading_config_id)
    trading_config = TradingConfig.find(trading_config_id)
    service = BinanceTradingService.new(trading_config)
    
    loop do
      opportunities = service.analyze_new_listings
      
      opportunities.each do |opportunity|
        if should_trade?(opportunity)
          execute_trade(service, trading_config, opportunity)
        end
      end
      
      sleep(trading_config.check_interval)
    end
  end
  
  private
  
  def should_trade?(opportunity)
    metrics = opportunity[:metrics]
    llm_analysis = opportunity[:llm_analysis]
    
    # Vérifier les conditions de trading
    metrics[:growth_rate] >= trading_config.min_growth_rate &&
    metrics[:volume] > minimum_volume &&
    llm_analysis[:confidence] > minimum_confidence
  end
  
  def execute_trade(service, trading_config, opportunity)
    symbol = opportunity[:symbol]
    amount = calculate_trade_amount(trading_config, opportunity)
    
    service.execute_trade(symbol, 'buy', amount)
  end
  
  def calculate_trade_amount(trading_config, opportunity)
    current_price = opportunity[:metrics][:current_price]
    max_amount = trading_config.max_investment_per_trade / current_price
    
    # Ajuster la quantité selon les règles de Binance
    max_amount.round(8)
  end
  
  def minimum_volume
    1000 # À ajuster selon vos besoins
  end
  
  def minimum_confidence
    0.7 # Seuil de confiance minimum pour le LLM
  end
end 