class TradingOrdersController < ApplicationController
  def index
    @dry_run = params[:dry_run] == 'true'
    @trading_service = BinanceTradingService.new(dry_run: @dry_run)
    
    # Récupérer les positions en base de données avec pagination
    @positions = TradingPosition.includes(:trades)
                               .where(dry_run: @dry_run)
                               .order(created_at: :desc)
                               .page(params[:page])
                               .per(20)
    
    # Récupérer les ordres depuis l'API Binance uniquement si pas en mode DRY
    @binance_orders = @dry_run ? [] : fetch_binance_orders
    
    # Calculer les statistiques
    @stats = calculate_stats
  end

  def show
    @position = TradingPosition.includes(:trades).find(params[:id])
    @dry_run = @position.dry_run
    @trading_service = BinanceTradingService.new(dry_run: @dry_run)
    
    # Récupérer les détails de l'ordre depuis Binance uniquement si pas en mode DRY
    @binance_order = @dry_run ? nil : fetch_binance_order_details(@position.symbol)
  end

  def refresh
    @dry_run = params[:dry_run] == 'true'
    @trading_service = BinanceTradingService.new(dry_run: @dry_run)
    
    # Synchroniser les ordres depuis Binance si pas en mode DRY
    unless @dry_run
      sync_binance_orders
    end
    
    redirect_to trading_orders_path(dry_run: @dry_run), notice: 'Ordres mis à jour avec succès'
  end

  private

  def fetch_binance_orders
    timestamp = Time.now.to_i * 1000
    params = { timestamp: timestamp, limit: 100 }
    signature = @trading_service.send(:generate_signature, params)

    response = HTTParty.get("#{@trading_service.class.base_uri}/api/v3/allOrders", {
      headers: {
        'X-MBX-APIKEY' => @trading_service.instance_variable_get(:@api_key)
      },
      query: params.merge(signature: signature)
    })

    return [] unless response.success?
    JSON.parse(response.body)
  end

  def fetch_binance_order_details(symbol)
    timestamp = Time.now.to_i * 1000
    params = { 
      symbol: symbol,
      timestamp: timestamp,
      limit: 10
    }
    signature = @trading_service.send(:generate_signature, params)

    response = HTTParty.get("#{@trading_service.class.base_uri}/api/v3/allOrders", {
      headers: {
        'X-MBX-APIKEY' => @trading_service.instance_variable_get(:@api_key)
      },
      query: params.merge(signature: signature)
    })

    return nil unless response.success?
    JSON.parse(response.body).first
  end

  def sync_binance_orders
    orders = fetch_binance_orders
    orders.each do |order_data|
      position = TradingPosition.find_or_initialize_by(
        symbol: order_data['symbol'],
        binance_order_id: order_data['orderId']
      )

      position.assign_attributes(
        entry_price: order_data['price'].to_f,
        quantity: order_data['executedQty'].to_f,
        status: order_data['status'].downcase,
        entry_time: Time.at(order_data['time'] / 1000),
        dry_run: false
      )

      position.save
    end
  end

  def calculate_stats
    {
      total_positions: @positions.total_count,
      open_positions: @positions.where(status: 'open').count,
      total_profit: @positions.sum(&:total_profit_percentage),
      win_rate: calculate_win_rate,
      average_profit: calculate_average_profit
    }
  end

  def calculate_win_rate
    closed_positions = @positions.where(status: 'closed')
    return 0 if closed_positions.empty?
    
    winning_positions = closed_positions.select { |p| p.total_profit_percentage > 0 }
    (winning_positions.count.to_f / closed_positions.count * 100).round(2)
  end

  def calculate_average_profit
    closed_positions = @positions.where(status: 'closed')
    return 0 if closed_positions.empty?
    
    (closed_positions.sum(&:total_profit_percentage) / closed_positions.count).round(2)
  end
end 