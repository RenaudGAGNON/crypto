class BinanceClient
  BASE_URL = 'https://api.binance.com/api/v3'

  def initialize
    @api_key = ENV['BINANCE_API_KEY']
    @api_secret = ENV['BINANCE_API_SECRET']
  end

  def get_ticker(symbol:)
    response = HTTP.get("#{BASE_URL}/ticker/24hr", params: { symbol: symbol })
    handle_response(response)
  end

  def get_klines(symbol:, interval:, limit: 24)
    response = HTTP.get("#{BASE_URL}/klines", params: {
      symbol: symbol,
      interval: interval,
      limit: limit
    })
    handle_response(response)
  end

  private

  def handle_response(response)
    case response.code
    when 200
      JSON.parse(response.body.to_s)
    when 429
      Rails.logger.error "Rate limit exceeded for Binance API"
      raise "Rate limit exceeded"
    else
      Rails.logger.error "Binance API error: #{response.code} - #{response.body}"
      raise "Binance API error: #{response.code}"
    end
  end
end 