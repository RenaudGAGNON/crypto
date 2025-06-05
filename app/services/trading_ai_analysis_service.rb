class TradingAiAnalysisService
  include HTTParty
  base_uri ENV["TRADING_AI_API_URL"]

  def initialize(provider = :chatgpt, model = nil)
    @llm_provider = LlmProviderService.new(provider, model)
    @cache = ActiveSupport::Cache::MemoryStore.new(expires_in: 5.minutes)
  end

  def analyze_chart(symbol, timeframe = "1h", limit = 100)
    begin
      # Vérifier le cache
      cache_key = "ai_analysis_#{symbol}_#{timeframe}_#{limit}"
      cached_analysis = @cache.read(cache_key)
      return cached_analysis if cached_analysis

      # Récupérer les données historiques
      klines = fetch_klines(symbol, timeframe, limit)
      return nil if klines.empty?

      # Préparer les données pour l'IA
      chart_data = format_chart_data(klines)

      # Envoyer à l'IA via le provider
      analysis = @llm_provider.analyze_chart(chart_data)
      return nil unless analysis

      # Enrichir l'analyse avec les métadonnées
      enriched_analysis = enrich_analysis(analysis, symbol, timeframe)

      # Mettre en cache
      @cache.write(cache_key, enriched_analysis)

      enriched_analysis
    rescue => e
      Rails.logger.error "Erreur lors de l'analyse IA pour #{symbol}: #{e.message}"
      nil
    end
  end

  private

  def fetch_klines(symbol, timeframe, limit)
    response = HTTParty.get("https://api.binance.com/api/v3/klines", {
      query: {
        symbol: symbol,
        interval: timeframe,
        limit: limit
      }
    })

    return [] unless response.success?

    JSON.parse(response.body).map do |kline|
      {
        timestamp: kline[0],
        open: kline[1].to_f,
        high: kline[2].to_f,
        low: kline[3].to_f,
        close: kline[4].to_f,
        volume: kline[5].to_f
      }
    end
  end

  def format_chart_data(klines)
    {
      candles: klines.map do |k|
        {
          time: Time.at(k[:timestamp] / 1000).iso8601,
          open: k[:open],
          high: k[:high],
          low: k[:low],
          close: k[:close],
          volume: k[:volume]
        }
      end,
      metadata: {
        total_candles: klines.size,
        timeframe: "1h",
        first_candle_time: Time.at(klines.first[:timestamp] / 1000).iso8601,
        last_candle_time: Time.at(klines.last[:timestamp] / 1000).iso8601
      }
    }
  end

  def enrich_analysis(analysis, symbol, timeframe)
    {
      symbol: symbol,
      timeframe: timeframe,
      timestamp: Time.current,
      confidence_score: analysis[:confidence_score],
      analysis: analysis[:analysis],
      raw_response: analysis[:raw_response],
      provider: @llm_provider.class.name
    }
  end
end
