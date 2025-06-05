require 'binance'

class BinanceTradingService
  include HTTParty
  base_uri 'https://api.binance.com'

  def initialize(dry_run: false)
    @api_key = ENV['BINANCE_API_KEY']
    @api_secret = ENV['BINANCE_API_SECRET']
    @dry_run = dry_run
  end

  def create_order(symbol:, side:, type:, quantity:, price: nil)
    timestamp = Time.now.to_i * 1000
    params = {
      symbol: symbol,
      side: side,
      type: type,
      quantity: quantity,
      timestamp: timestamp
    }
    params[:price] = price if price

    if @dry_run
      # Simuler une réponse d'ordre en mode DRY
      simulated_order = simulate_order(params)
      save_order_to_db(simulated_order)
      simulated_order
    else
      # Exécuter l'ordre réel via l'API
      signature = generate_signature(params)
      response = HTTParty.post("#{self.class.base_uri}/api/v3/order", {
        headers: {
          'X-MBX-APIKEY' => @api_key
        },
        query: params.merge(signature: signature)
      })

      if response.success?
        order_data = JSON.parse(response.body)
        save_order_to_db(order_data)
        order_data
      else
        Rails.logger.error("Erreur lors de la création de l'ordre: #{response.body}")
        nil
      end
    end
  end

  def get_order(symbol:, order_id:)
    timestamp = Time.now.to_i * 1000
    params = {
      symbol: symbol,
      orderId: order_id,
      timestamp: timestamp
    }

    if @dry_run
      # Retourner l'ordre simulé depuis la DB
      TradingPosition.find_by(symbol: symbol, binance_order_id: order_id)
    else
      signature = generate_signature(params)
      response = HTTParty.get("#{self.class.base_uri}/api/v3/order", {
        headers: {
          'X-MBX-APIKEY' => @api_key
        },
        query: params.merge(signature: signature)
      })

      return nil unless response.success?
      JSON.parse(response.body)
    end
  end

  def get_account_balance
    timestamp = Time.now.to_i * 1000
    params = { timestamp: timestamp }
    signature = generate_signature(params)

    response = self.class.get('/api/v3/account', {
      headers: {
        'X-MBX-APIKEY' => @api_key
      },
      query: params.merge(signature: signature)
    })

    return [] unless response.success?
    response['balances'].select { |b| b['free'].to_f > 0 }
  end

  def get_symbol_info(symbol)
    response = self.class.get('/api/v3/exchangeInfo', {
      query: { symbol: symbol }
    })

    return nil unless response.success?
    response['symbols'].find { |s| s['symbol'] == symbol }
  end

  def calculate_position_size(symbol, risk_percentage = 5)
    # Récupérer le solde USDT disponible
    balance = get_account_balance
    usdt_balance = balance.find { |b| b['asset'] == 'USDT' }
    return 0 unless usdt_balance

    available_usdt = usdt_balance['free'].to_f
    risk_amount = available_usdt * (risk_percentage / 100.0)

    # Récupérer le prix actuel
    ticker = get_ticker_price(symbol)
    return 0 unless ticker

    current_price = ticker['price'].to_f
    quantity = risk_amount / current_price

    # Arrondir la quantité selon les règles du symbole
    symbol_info = get_symbol_info(symbol)
    return 0 unless symbol_info

    lot_size_filter = symbol_info['filters'].find { |f| f['filterType'] == 'LOT_SIZE' }
    if lot_size_filter
      step_size = lot_size_filter['stepSize'].to_f
      quantity = (quantity / step_size).floor * step_size
    end

    quantity
  end

  private

  def get_ticker_price(symbol)
    response = self.class.get('/api/v3/ticker/price', {
      query: { symbol: symbol }
    })

    return nil unless response.success?
    response
  end

  def generate_signature(params)
    query_string = params.map { |k, v| "#{k}=#{v}" }.join('&')
    OpenSSL::HMAC.hexdigest('sha256', @api_secret, query_string)
  end

  def simulate_order(params)
    {
      'symbol' => params[:symbol],
      'orderId' => SecureRandom.hex(8),
      'clientOrderId' => SecureRandom.hex(8),
      'transactTime' => Time.now.to_i * 1000,
      'price' => params[:price],
      'origQty' => params[:quantity],
      'executedQty' => params[:quantity],
      'status' => 'FILLED',
      'timeInForce' => 'GTC',
      'type' => params[:type],
      'side' => params[:side]
    }
  end

  def save_order_to_db(order_data)
    position = TradingPosition.find_or_initialize_by(
      symbol: order_data['symbol'],
      binance_order_id: order_data['orderId']
    )

    position.assign_attributes(
      entry_price: order_data['price'].to_f,
      quantity: order_data['executedQty'].to_f,
      status: order_data['status'].downcase,
      entry_time: Time.at(order_data['transactTime'] / 1000),
      dry_run: @dry_run
    )

    position.save
  end
end 