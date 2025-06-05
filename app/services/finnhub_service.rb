class FinnhubService
  def initialize
    @client = FinnhubRuby::DefaultApi.new
  end

  def get_crypto_quote(symbol)
    begin
      # Utiliser crypto_profile pour obtenir les informations de base
      profile = @client.crypto_profile(symbol)
      
      # Utiliser crypto_candles pour obtenir les prix
      candles = @client.crypto_candles(symbol, 'D', (Time.now - 1.day).to_i, Time.now.to_i)
      
      return nil unless profile && candles && !candles.empty?
      
      {
        current_price: candles.last[:close],
        high_price: candles.last[:high],
        low_price: candles.last[:low],
        open_price: candles.last[:open],
        previous_close: candles[-2][:close]
      }
    rescue FinnhubRuby::ApiError => e
      Rails.logger.error "Erreur Finnhub API: #{e.message}"
      nil
    end
  end

  def get_crypto_candles(symbol, resolution, from, to)
    begin
      response = @client.crypto_candles(symbol, resolution, from, to)
      
      return nil unless response && response[:s] == 'ok'
      
      {
        close_prices: response[:c],
        volumes: response[:v],
        timestamps: response[:t]
      }
    rescue FinnhubRuby::ApiError => e
      Rails.logger.error "Erreur Finnhub API: #{e.message}"
      nil
    end
  end

  def get_news(symbol)
    begin
      # Utiliser news pour obtenir les articles liés à la crypto
      response = @client.news(symbol)
      
      return [] unless response
      
      response.map do |article|
        {
          headline: article[:headline],
          summary: article[:summary],
          sentiment: calculate_sentiment(article[:summary])
        }
      end
    rescue FinnhubRuby::ApiError => e
      Rails.logger.error "Erreur Finnhub API: #{e.message}"
      []
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