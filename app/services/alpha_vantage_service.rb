class AlphaVantageService
  include HTTParty
  base_uri 'https://www.alphavantage.co'

  def initialize
    @api_key = ENV['ALPHA_VANTAGE_API_KEY']
  end

  def get_crypto_quote(symbol)
    begin
      # Convertir le symbole USDT en format Alpha Vantage
      crypto_symbol = symbol.gsub('USDT', '')
      
      response = self.class.get('/query', query: {
        function: 'DIGITAL_CURRENCY_DAILY',
        symbol: crypto_symbol,
        market: 'USD',
        apikey: @api_key
      })

      return nil unless response.success? && response['Time Series (Digital Currency Daily)']

      latest_data = response['Time Series (Digital Currency Daily)'].values.first
      {
        current_price: latest_data['4a. close (USD)'].to_f,
        high_price: latest_data['2a. high (USD)'].to_f,
        low_price: latest_data['3a. low (USD)'].to_f,
        open_price: latest_data['1a. open (USD)'].to_f,
        previous_close: latest_data['4a. close (USD)'].to_f
      }
    rescue => e
      Rails.logger.error "Erreur Alpha Vantage API: #{e.message}"
      nil
    end
  end

  def get_crypto_candles(symbol, resolution, from, to)
    begin
      # Convertir le symbole USDT en format Alpha Vantage
      crypto_symbol = symbol.gsub('USDT', '')
      
      # Alpha Vantage utilise des intervalles différents
      interval = case resolution
                 when 'D' then 'daily'
                 when '1' then '1min'
                 when '5' then '5min'
                 when '15' then '15min'
                 when '30' then '30min'
                 when '60' then '60min'
                 else 'daily'
                 end

      function = interval == 'daily' ? 'DIGITAL_CURRENCY_DAILY' : 'DIGITAL_CURRENCY_INTRADAY'
      
      response = self.class.get('/query', query: {
        function: function,
        symbol: crypto_symbol,
        market: 'USD',
        interval: interval,
        apikey: @api_key
      })

      return nil unless response.success?

      time_series_key = interval == 'daily' ? 'Time Series (Digital Currency Daily)' : "Time Series (Digital Currency Intraday)"
      time_series = response[time_series_key]

      return nil unless time_series

      {
        close_prices: time_series.values.map { |data| data['4a. close (USD)'].to_f },
        volumes: time_series.values.map { |data| data['5. volume'].to_f },
        timestamps: time_series.keys.map { |timestamp| Time.parse(timestamp).to_i }
      }
    rescue => e
      Rails.logger.error "Erreur Alpha Vantage API: #{e.message}"
      nil
    end
  end

  def get_news(symbol)
    begin
      # Alpha Vantage ne fournit pas directement de news
      # Nous utiliserons une source alternative ou retournerons un tableau vide
      []
    rescue => e
      Rails.logger.error "Erreur Alpha Vantage API: #{e.message}"
      []
    end
  end

  def get_top_movers
    begin
      response = self.class.get('/query', query: {
        function: 'TOP_GAINERS_LOSERS',
        apikey: @api_key
      })
      
      return nil unless response.success? && response['top_gainers']

      {
        top_gainers: response['top_gainers'].map do |gainer|
          {
            symbol: gainer['ticker'],
            price: gainer['price'].to_f,
            change_percentage: gainer['change_percentage'].to_f,
            volume: gainer['volume'].to_f
          }
        end,
        top_losers: response['top_losers'].map do |loser|
          {
            symbol: loser['ticker'],
            price: loser['price'].to_f,
            change_percentage: loser['change_percentage'].to_f,
            volume: loser['volume'].to_f
          }
        end,
        most_actively_traded: response['most_actively_traded'].map do |active|
          {
            symbol: active['ticker'],
            price: active['price'].to_f,
            change_percentage: active['change_percentage'].to_f,
            volume: active['volume'].to_f
          }
        end
      }
    rescue => e
      Rails.logger.error "Erreur Alpha Vantage API (Top Movers): #{e.message}"
      nil
    end
  end

  private

  def calculate_sentiment(text)
    # Analyse de sentiment simple basée sur des mots-clés
    positive_words = ['up', 'rise', 'gain', 'bullish', 'positive', 'growth', 'success']
    negative_words = ['down', 'fall', 'loss', 'bearish', 'negative', 'decline', 'failure']
    
    words = text.downcase.split
    positive_count = words.count { |word| positive_words.include?(word) }
    negative_count = words.count { |word| negative_words.include?(word) }
    
    total = positive_count + negative_count
    return 0.5 if total == 0
    
    positive_count.to_f / total
  end
end 