class BinanceMonitorService
  include HTTParty
  base_uri "https://api.binance.com"

  # Constantes de base pour les indicateurs techniques
  BASE_INDICATORS = {
    volume_spike_multiplier: 1.2,
    rsi_threshold: 55.0,
    upper_wick_percentage: 4.0,
    vwap_period: 20,
    ema_fast: 5,
    ema_slow: 20,
    macd_fast: 12,
    macd_slow: 26,
    macd_signal: 9
  }.freeze

  # Seuils minimum pour éviter des conditions trop permissives
  MIN_INDICATORS = {
    volume_spike_multiplier: 1.05,
    rsi_threshold: 40.0,
    upper_wick_percentage: 5.0
  }.freeze

  LISTING_MONITORING_PERIOD = 1.week
  CACHE_EXPIRY = 10.minutes
  EXCHANGE_INFO_CACHE_KEY = "binance_exchange_info"
  KLINES_CACHE_PREFIX = "binance_klines_"

  def initialize
    @telegram_bot_token = ENV["TELEGRAM_BOT_TOKEN"]
    @telegram_chat_id = ENV["TELEGRAM_CHAT_ID"]
    @storage_path = Rails.root.join("tmp", "storage", "binance")
    @reference_file = @storage_path.join("reference_pairs.json")
    @websocket_connections = {}
    @trading_service = BinanceTradingService.new
    @client = BinanceClient.new
    @ws_client = nil
    @reconnect_attempts = 0
    @max_reconnect_attempts = 5
    @reconnect_delay = 5 # secondes
    @indicators = BASE_INDICATORS.dup
    @no_results_count = 0
    @cache = ActiveSupport::Cache::MemoryStore.new(expires_in: CACHE_EXPIRY)
    @monitoring_thread = nil
    @is_monitoring = false
    @ai_analysis_service = TradingAiAnalysisService.new(:chatgpt)
    @claude_analysis_service = TradingAiAnalysisService.new(:claude, :sonnet)
  end

  def start_monitoring
    return if @is_monitoring
    Rails.logger.info "Démarrage de la surveillance Binance"
    @is_monitoring = true
    connect_websocket
    start_periodic_check
  end

  def stop_monitoring
    Rails.logger.info "Arrêt de la surveillance Binance"
    @is_monitoring = false
    @monitoring_thread&.exit
    @monitoring_thread = nil
    @ws_client&.close
    @ws_client = nil
  end

  def start_periodic_check
    return if @monitoring_thread&.alive?

    @monitoring_thread = Thread.new do
      while @is_monitoring
        begin
          check_new_listings
          sleep(5.minutes)
        rescue => e
          Rails.logger.error "Erreur dans la boucle de monitoring: #{e.message}"
          sleep(1.minute) # Attendre un peu en cas d'erreur
        end
      end
    end
  end

  def check_new_listings
    return unless @is_monitoring

    begin
      exchange_info = fetch_exchange_info
      return unless exchange_info

      current_time = Time.now
      new_listings = []
      all_symbols = exchange_info["symbols"].select { |s| s["status"] == "TRADING" && s["quoteAsset"] == "USDT" && s["symbol"].end_with?("USDT") }

      # Mettre à jour les symboles existants
      existing_symbols = ListingHistory.pluck(:symbol)
      all_symbols.each do |symbol|
        if existing_symbols.include?(symbol["symbol"])
          ListingHistory.update_last_seen(symbol["symbol"])
        end
      end

      # Marquer comme inactifs les symboles qui ne sont plus dans la liste
      (existing_symbols - all_symbols.map { |s| s["symbol"] }).each do |symbol|
        ListingHistory.mark_as_inactive(symbol)
      end

      # Vérifier les symboles manquants dans l'historique
      missing_symbols = all_symbols.reject { |s| existing_symbols.include?(s["symbol"]) }

      # Enregistrer les symboles manquants
      missing_symbols.each do |symbol|
        record_listing_time(symbol["symbol"], current_time)
        new_listings << format_listing(symbol, current_time, calculate_growth_percentage(symbol["symbol"]))
        start_realtime_monitoring(symbol["symbol"])
      end

      # Vérifier les symboles existants dans la période de monitoring
      existing_symbols.each do |symbol|
        if is_new_listing?(symbol)
          symbol_info = all_symbols.find { |s| s["symbol"] == symbol }
          if symbol_info
            new_listings << format_listing(symbol_info, current_time, calculate_growth_percentage(symbol))
            start_realtime_monitoring(symbol)
          end
        end
      end

      handle_listings_result(new_listings)
      new_listings
    rescue => e
      Rails.logger.error "Erreur Binance Monitor: #{e.message}"
      nil
    end
  end

  private

  def connect_websocket
    return if @ws_client&.connected?

    begin
      @ws_client = Binance::WebSocket.new

      # Gestionnaire de fermeture
      @ws_client.on_close do |code, reason|
        Rails.logger.warn "WebSocket fermé (code: #{code}, raison: #{reason})"
        handle_websocket_close
      end

      # Gestionnaire d'erreur
      @ws_client.on_error do |error|
        Rails.logger.error "Erreur WebSocket: #{error.message}"
        handle_websocket_error(error)
      end

      # Gestionnaire de message
      @ws_client.on_message do |message|
        handle_message(message)
      end

      # Connexion au stream des nouveaux listings
      @ws_client.subscribe("!ticker@arr")

      Rails.logger.info "WebSocket connecté avec succès"
      @reconnect_attempts = 0
    rescue => e
      Rails.logger.error "Erreur lors de la connexion WebSocket: #{e.message}"
      handle_websocket_error(e)
    end
  end

  def handle_websocket_close
    if @reconnect_attempts < @max_reconnect_attempts
      @reconnect_attempts += 1
      delay = @reconnect_delay * @reconnect_attempts
      Rails.logger.info "Tentative de reconnexion dans #{delay} secondes (tentative #{@reconnect_attempts}/#{@max_reconnect_attempts})"

      # Planifier la reconnexion
      Thread.new do
        sleep delay
        connect_websocket
      end
    else
      Rails.logger.error "Nombre maximum de tentatives de reconnexion atteint"
      # Notifier l'administrateur ou le système de monitoring
      notify_connection_failure
    end
  end

  def handle_websocket_error(error)
    Rails.logger.error "Erreur WebSocket: #{error.message}"
    handle_websocket_close
  end

  def handle_message(message)
    data = JSON.parse(message)
    return unless data["e"] == "ticker"

    symbol = data["s"]
    return unless is_new_listing?(symbol)

    # Analyser le nouveau listing
    analyze_new_listing(symbol)
  end

  def record_listing_time(symbol, time)
    # Enregistrer dans l'historique des listings
    ListingHistory.find_or_create_by(symbol: symbol) do |listing|
      listing.first_seen_at = time
    end

    # Créer ou mettre à jour l'enregistrement du temps de listing
    listing = TradingPosition.find_or_initialize_by(symbol: symbol)

    # S'assurer que toutes les validations sont respectées
    listing.assign_attributes(
      trading_config: TradingConfig.first, # Assurez-vous d'avoir une config par défaut
      entry_price: 0.0001, # Valeur fictive > 0
      quantity: 0.0001,    # Valeur fictive > 0
      status: "open",
      entry_time: time,
      take_profit_levels: [
        { price: 0.00011, percentage: 10, status: "pending" },
        { price: 0.000125, percentage: 25, status: "pending" },
        { price: 0.00015, percentage: 50, status: "pending" }
      ],
      stop_loss: 0.00009 # Valeur fictive > 0
    )

    if listing.save
      Rails.logger.info "Temps de listing enregistré pour #{symbol}: #{time}"
    else
      Rails.logger.error "Erreur lors de l'enregistrement du listing pour #{symbol}: #{listing.errors.full_messages.join(', ')}"
    end
  end

  def is_new_listing?(symbol)
    listing = ListingHistory.find_by(symbol: symbol)
    return true unless listing&.first_seen_at
    (Time.current - listing.first_seen_at) <= LISTING_MONITORING_PERIOD
  end

  def analyze_new_listing(symbol)
    Rails.logger.info "Analyse du nouveau listing: #{symbol}"

    begin
      # Récupérer les données historiques
      klines = @client.get_klines(
        symbol: symbol,
        interval: "1h",
        limit: 24
      )

      return if klines.empty?

      # Calculer les indicateurs
      indicators = calculate_indicators(symbol, klines.last)

      # Vérifier les conditions d'achat
      if check_buy_conditions(indicators)
        Rails.logger.info "Signal d'achat détecté pour #{symbol}"
        create_trading_position(symbol, indicators)
      end
    rescue => e
      Rails.logger.error "Erreur lors de l'analyse de #{symbol}: #{e.message}"
    end
  end

  def notify_connection_failure
    # TODO: Implémenter la notification (email, Slack, etc.)
    Rails.logger.error "Échec de la connexion WebSocket après #{@max_reconnect_attempts} tentatives"
  end

  def start_realtime_monitoring(symbol)
    return if @websocket_connections[symbol]

    # Regrouper les streams pour réduire le nombre de connexions
    streams = [
      "#{symbol.downcase}@kline_1m",
      "#{symbol.downcase}@kline_3m",
      "#{symbol.downcase}@trade"
    ].join("/")

    ws_url = "wss://stream.binance.com:9443/stream?streams=#{streams}"

    EM.run do
      ws = Faye::WebSocket::Client.new(ws_url)

      ws.on :message do |event|
        data = JSON.parse(event.data)
        process_realtime_data(symbol, data)
      end

      ws.on :close do |event|
        Rails.logger.info "WebSocket fermé pour #{symbol}: #{event.code} #{event.reason}"
        @websocket_connections.delete(symbol)
      end

      @websocket_connections[symbol] = ws
    end
  end

  def process_realtime_data(symbol, data)
    return unless data["e"] == "kline"

    candle = data["k"]
    return unless candle["x"] # Bougie complétée

    Rails.logger.info "=== Analyse en temps réel pour #{symbol} ==="
    Rails.logger.info "Bougie complétée:"
    Rails.logger.info "  - Open: #{candle['o']}"
    Rails.logger.info "  - High: #{candle['h']}"
    Rails.logger.info "  - Low: #{candle['l']}"
    Rails.logger.info "  - Close: #{candle['c']}"
    Rails.logger.info "  - Volume: #{candle['v']}"

    # Calculer les indicateurs techniques
    indicators = calculate_indicators(symbol, candle)

    # Analyse IA avec ChatGPT
    chatgpt_analysis = @ai_analysis_service.analyze_chart(symbol, "1w", 100)
    if chatgpt_analysis
      Rails.logger.info "\nAnalyse ChatGPT:"
      log_ai_analysis(chatgpt_analysis)
    end

    # Analyse IA avec Claude
    claude_analysis = @claude_analysis_service.analyze_chart(symbol, "1w", 100)
    if claude_analysis
      Rails.logger.info "\nAnalyse Claude:"
      log_ai_analysis(claude_analysis)
    end

    # Vérifier les scores de confiance
    chatgpt_confidence = chatgpt_analysis&.dig(:confidence_score).to_i
    claude_confidence = claude_analysis&.dig(:confidence_score).to_i

    # Prendre le meilleur score
    best_confidence = [ chatgpt_confidence, claude_confidence ].max
    if best_confidence < 70
      Rails.logger.info "\nMeilleur score de confiance trop faible (#{best_confidence}/100)"
      return
    end

    # Vérifier les conditions d'achat
    if check_buy_conditions(indicators)
      execute_buy_order(symbol, indicators)
    end

    # Vérifier les conditions de vente pour les positions ouvertes
    check_sell_conditions(symbol, indicators)
  end

  def calculate_indicators(symbol, candle)
    # Récupérer les données historiques pour les calculs
    klines = fetch_klines(symbol)

    # Calculer les moyennes mobiles
    ema5 = calculate_ema(klines, @indicators[:ema_fast])
    ema20 = calculate_ema(klines, @indicators[:ema_slow])

    # Calculer le RSI
    rsi = calculate_rsi(klines)

    # Calculer le MACD
    macd = calculate_macd(klines)

    # Calculer le VWAP
    vwap = calculate_vwap(klines)

    # Calculer le volume moyen
    volume_ma = calculate_volume_ma(klines, @indicators[:vwap_period])

    {
      current_price: candle["c"].to_f,
      volume: candle["v"].to_f,
      volume_ma: volume_ma,
      ema5: ema5,
      ema20: ema20,
      rsi: rsi,
      macd: macd,
      vwap: vwap,
      high: candle["h"].to_f,
      low: candle["l"].to_f,
      open: candle["o"].to_f,
      close: candle["c"].to_f
    }
  end

  def check_buy_conditions(indicators)
    Rails.logger.info "=== Vérification des conditions d'achat ==="

    # Analyse IA
    ai_analysis = @ai_analysis_service.analyze_chart(indicators[:symbol])
    if ai_analysis
      Rails.logger.info "\nAnalyse IA:"
      Rails.logger.info "  - Score de confiance: #{ai_analysis[:confidence_score]}"
      Rails.logger.info "  - Force de la tendance: #{ai_analysis[:analysis][:trend_strength]}"
      Rails.logger.info "  - Reconnaissance de pattern: #{ai_analysis[:analysis][:pattern_recognition]}"
      Rails.logger.info "  - Analyse du volume: #{ai_analysis[:analysis][:volume_analysis]}"
      Rails.logger.info "  - Évaluation du risque: #{ai_analysis[:analysis][:risk_assessment]}"
      Rails.logger.info "  - Recommandations: #{ai_analysis[:recommendations]}"
    end

    # Vérification du score de confiance IA
    ai_confidence = ai_analysis&.dig(:confidence_score).to_i
    if ai_confidence < 70
      Rails.logger.info "\nScore de confiance IA trop faible (#{ai_confidence}/100)"
      return false
    end

    Rails.logger.info "Indicateurs actuels:"
    Rails.logger.info "  - Volume spike multiplier: #{@indicators[:volume_spike_multiplier]}"
    Rails.logger.info "  - RSI threshold: #{@indicators[:rsi_threshold]}"
    Rails.logger.info "  - Upper wick percentage: #{@indicators[:upper_wick_percentage]}"
    Rails.logger.info "  - VWAP period: #{@indicators[:vwap_period]}"
    Rails.logger.info "  - EMA fast: #{@indicators[:ema_fast]}"
    Rails.logger.info "  - EMA slow: #{@indicators[:ema_slow]}"
    Rails.logger.info "  - MACD fast: #{@indicators[:macd_fast]}"
    Rails.logger.info "  - MACD slow: #{@indicators[:macd_slow]}"
    Rails.logger.info "  - MACD signal: #{@indicators[:macd_signal]}"

    Rails.logger.info "\nValeurs calculées:"
    Rails.logger.info "  - Prix actuel: #{indicators[:current_price]}"
    Rails.logger.info "  - Volume: #{indicators[:volume]}"
    Rails.logger.info "  - Volume MA: #{indicators[:volume_ma]}"
    Rails.logger.info "  - EMA5: #{indicators[:ema5]}"
    Rails.logger.info "  - EMA20: #{indicators[:ema20]}"
    Rails.logger.info "  - RSI: #{indicators[:rsi]}"
    Rails.logger.info "  - VWAP: #{indicators[:vwap]}"
    Rails.logger.info "  - MACD: #{indicators[:macd][:macd]}"
    Rails.logger.info "  - MACD Signal: #{indicators[:macd][:signal]}"
    Rails.logger.info "  - MACD Histogram: #{indicators[:macd][:histogram]}"
    Rails.logger.info "  - High: #{indicators[:high]}"
    Rails.logger.info "  - Low: #{indicators[:low]}"
    Rails.logger.info "  - Open: #{indicators[:open]}"
    Rails.logger.info "  - Close: #{indicators[:close]}"

    # Volume spike
    volume_spike = indicators[:volume] > (indicators[:volume_ma] * @indicators[:volume_spike_multiplier])
    Rails.logger.info "\nVérification Volume spike:"
    Rails.logger.info "  - Volume actuel: #{indicators[:volume]}"
    Rails.logger.info "  - Volume MA: #{indicators[:volume_ma]}"
    Rails.logger.info "  - Multiplicateur requis: #{@indicators[:volume_spike_multiplier]}"
    Rails.logger.info "  - Volume minimum requis: #{indicators[:volume_ma] * @indicators[:volume_spike_multiplier]}"
    Rails.logger.info "  - Résultat: #{volume_spike}"

    # Prix au-dessus du VWAP
    above_vwap = indicators[:current_price] > indicators[:vwap]
    Rails.logger.info "\nVérification Prix/VWAP:"
    Rails.logger.info "  - Prix actuel: #{indicators[:current_price]}"
    Rails.logger.info "  - VWAP: #{indicators[:vwap]}"
    Rails.logger.info "  - Résultat: #{above_vwap}"

    # RSI
    strong_rsi = indicators[:rsi] > @indicators[:rsi_threshold]
    Rails.logger.info "\nVérification RSI:"
    Rails.logger.info "  - RSI actuel: #{indicators[:rsi]}"
    Rails.logger.info "  - Seuil requis: #{@indicators[:rsi_threshold]}"
    Rails.logger.info "  - Résultat: #{strong_rsi}"

    # EMA
    bullish_ema = indicators[:ema5] > indicators[:ema20]
    Rails.logger.info "\nVérification EMA:"
    Rails.logger.info "  - EMA5: #{indicators[:ema5]}"
    Rails.logger.info "  - EMA20: #{indicators[:ema20]}"
    Rails.logger.info "  - Résultat: #{bullish_ema}"

    # MACD
    bullish_macd = indicators[:macd][:signal] > indicators[:macd][:histogram]
    Rails.logger.info "\nVérification MACD:"
    Rails.logger.info "  - MACD Signal: #{indicators[:macd][:signal]}"
    Rails.logger.info "  - MACD Histogram: #{indicators[:macd][:histogram]}"
    Rails.logger.info "  - Résultat: #{bullish_macd}"

    # Mèche haute
    upper_wick = indicators[:high] - [ indicators[:open], indicators[:close] ].max
    upper_wick_percentage = (upper_wick / indicators[:high] * 100).round(2)
    no_upper_wick = upper_wick < (indicators[:high] * @indicators[:upper_wick_percentage] / 100)
    Rails.logger.info "\nVérification Mèche haute:"
    Rails.logger.info "  - Taille de la mèche: #{upper_wick}"
    Rails.logger.info "  - Pourcentage de la mèche: #{upper_wick_percentage}%"
    Rails.logger.info "  - Seuil maximum: #{@indicators[:upper_wick_percentage]}%"
    Rails.logger.info "  - Résultat: #{no_upper_wick}"

    result = volume_spike && above_vwap && strong_rsi && bullish_ema && bullish_macd && no_upper_wick
    Rails.logger.info "\nRésultat final des conditions: #{result}"
    Rails.logger.info "=== Fin de la vérification ===\n"

    result
  end

  def execute_buy_order(symbol, indicators)
    # Vérifier si nous n'avons pas déjà une position ouverte
    return if TradingPosition.exists?(symbol: symbol, status: "open")

    # Calculer la taille de la position (par exemple 5% du portefeuille)
    position_size = calculate_position_size(symbol)

    # Créer l'ordre d'achat
    order = create_buy_order(symbol, position_size)

    if order["status"] == "FILLED"
      # Enregistrer la position
      TradingPosition.create!(
        symbol: symbol,
        entry_price: indicators[:current_price],
        quantity: order["executedQty"],
        status: "open",
        entry_time: Time.now,
        take_profit_levels: [
          { price: indicators[:current_price] * 1.10, percentage: 10, status: "pending" },
          { price: indicators[:current_price] * 1.25, percentage: 25, status: "pending" },
          { price: indicators[:current_price] * 1.50, percentage: 50, status: "pending" }
        ],
        stop_loss: indicators[:current_price] * 0.95
      )

      # Notifier l'achat
      send_telegram_message("🟢 Achat exécuté pour #{symbol}\nPrix: #{indicators[:current_price]}\nQuantité: #{order['executedQty']}")
    end
  end

  def check_sell_conditions(symbol, indicators)
    position = TradingPosition.find_by(symbol: symbol, status: "open")
    return unless position

    current_price = indicators[:current_price]

    # Vérifier les take profits
    position.take_profit_levels.each do |level|
      if level["status"] == "pending" && current_price >= level["price"]
        execute_partial_sell(position, level)
      end
    end

    # Vérifier le stop loss
    if current_price <= position.stop_loss
      execute_stop_loss(position)
    end

    # Vérifier le timeout (15 minutes)
    if Time.now - position.entry_time > 15.minutes
      execute_timeout_sell(position)
    end
  end

  def execute_partial_sell(position, level)
    # Calculer la quantité à vendre (33% de la position)
    quantity = position.quantity * 0.33

    # Créer l'ordre de vente
    order = create_sell_order(position.symbol, quantity)

    if order["status"] == "FILLED"
      # Mettre à jour la position
      level["status"] = "executed"
      position.quantity -= quantity
      position.save!

      # Enregistrer le trade
      Trade.create!(
        position: position,
        type: "take_profit",
        price: order["price"],
        quantity: quantity,
        profit_percentage: level["percentage"]
      )

      # Notifier la vente
      send_telegram_message("💰 Take Profit #{level['percentage']}% exécuté pour #{position.symbol}\nPrix: #{order['price']}\nQuantité: #{quantity}")
    end
  end

  def execute_stop_loss(position)
    order = create_sell_order(position.symbol, position.quantity)

    if order["status"] == "FILLED"
      # Mettre à jour la position
      position.status = "closed"
      position.save!

      # Enregistrer le trade
      Trade.create!(
        position: position,
        type: "stop_loss",
        price: order["price"],
        quantity: position.quantity,
        profit_percentage: ((order["price"] - position.entry_price) / position.entry_price * 100).round(2)
      )

      # Notifier la vente
      send_telegram_message("🔴 Stop Loss exécuté pour #{position.symbol}\nPrix: #{order['price']}\nQuantité: #{position.quantity}")
    end
  end

  def execute_timeout_sell(position)
    order = create_sell_order(position.symbol, position.quantity)

    if order["status"] == "FILLED"
      # Mettre à jour la position
      position.status = "closed"
      position.save!

      # Enregistrer le trade
      Trade.create!(
        position: position,
        type: "timeout",
        price: order["price"],
        quantity: position.quantity,
        profit_percentage: ((order["price"] - position.entry_price) / position.entry_price * 100).round(2)
      )

      # Notifier la vente
      send_telegram_message("⏰ Vente timeout pour #{position.symbol}\nPrix: #{order['price']}\nQuantité: #{position.quantity}")
    end
  end

  # Méthodes utilitaires pour les calculs techniques
  def calculate_ema(klines, period)
    puts "----------- Klines ---------------"
    puts klines
    puts "--------------------------------"
    prices = klines.map { |k| k[:close] }
    multiplier = 2.0 / (period + 1)
    ema = prices.first

    prices[1..-1].each do |price|
      ema = (price - ema) * multiplier + ema
    end

    ema
  end

  def calculate_rsi(klines, period = 14)
    prices = klines.map { |k| k[:close] }
    changes = prices.each_cons(2).map { |a, b| b - a }

    gains = changes.map { |change| [ change, 0 ].max }
    losses = changes.map { |change| [ change.abs, 0 ].max }

    avg_gain = gains.last(period).sum / period
    avg_loss = losses.last(period).sum / period

    return 50 if avg_loss.zero?

    rs = avg_gain / avg_loss
    100 - (100 / (1 + rs))
  end

  def calculate_macd(klines)
    prices = klines.map { |k| k[:close] }
    ema12 = calculate_ema(klines, @indicators[:macd_fast])
    ema26 = calculate_ema(klines, @indicators[:macd_slow])
    macd_line = ema12 - ema26

    # Créer un format de klines pour la ligne de signal
    signal_klines = [ { close: macd_line } ]
    signal_line = calculate_ema(signal_klines, @indicators[:macd_signal])

    {
      macd: macd_line,
      signal: signal_line,
      histogram: macd_line - signal_line
    }
  end

  def calculate_vwap(klines)
    total_volume = 0
    total_pv = 0

    klines.each do |k|
      price = (k[:open] + k[:high] + k[:low] + k[:close]) / 4
      volume = k[:volume]
      total_pv += price * volume
      total_volume += volume
    end

    total_pv / total_volume
  end

  def calculate_volume_ma(klines, period)
    volumes = klines.map { |k| k[:volume] }
    volumes.last(period).sum / period
  end

  def fetch_klines(symbol, interval = "1h", limit = 24)
    cache_key = "#{KLINES_CACHE_PREFIX}#{symbol}_#{interval}_#{limit}"
    cached_klines = @cache.read(cache_key)
    return cached_klines if cached_klines

    response = HTTParty.get("#{self.class.base_uri}/api/v3/klines", {
      query: {
        symbol: symbol,
        interval: interval,
        limit: limit
      }
    })

    return [] unless response.success?

    begin
      klines = JSON.parse(response.body)
      formatted_klines = klines.map do |kline|
        {
          open_time: Time.at(kline[0] / 1000),
          open: kline[1].to_f,
          high: kline[2].to_f,
          low: kline[3].to_f,
          close: kline[4].to_f,
          volume: kline[5].to_f,
          close_time: Time.at(kline[6] / 1000),
          quote_volume: kline[7].to_f,
          trades: kline[8].to_i,
          taker_buy_base: kline[9].to_f,
          taker_buy_quote: kline[10].to_f
        }
      end

      @cache.write(cache_key, formatted_klines, expires_in: CACHE_EXPIRY)
      formatted_klines
    rescue StandardError => e
      Rails.logger.error("Erreur lors du traitement des klines pour #{symbol}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      []
    end
  end

  def calculate_growth_percentage(symbol)
    klines = fetch_klines(symbol)
    return nil if klines.empty?

    begin
      current_price = klines.last[:close]
      previous_price = klines.first[:close]

      ((current_price - previous_price) / previous_price * 100).round(2)
    rescue StandardError => e
      Rails.logger.error("Erreur lors du calcul de la croissance pour #{symbol}: #{e.message}")
      nil
    end
  end

  def create_buy_order(symbol, quantity)
    @trading_service.create_buy_order(symbol, quantity)
  end

  def create_sell_order(symbol, quantity)
    @trading_service.create_sell_order(symbol, quantity)
  end

  def calculate_position_size(symbol)
    @trading_service.calculate_position_size(symbol)
  end

  def detect_new_listings(symbols, reference_pairs, current_time)
    new_listings = []

    symbols.each do |symbol|
      next unless symbol["status"] == "TRADING" # Vérifier si la paire est en trading

      # Vérifier si c'est une nouvelle paire USDT
      if symbol["quoteAsset"] == "USDT" && symbol["symbol"].end_with?("USDT")
        # Vérifier si c'est une nouvelle paire
        unless reference_pairs.include?(symbol["symbol"])
          # Calculer les opportunités de croissance
          growth_opportunities = calculate_growth_percentage(symbol["symbol"])

          new_listings << format_listing(symbol, current_time, growth_opportunities)
        end
      end
    end

    new_listings
  end

  def format_listing(symbol, current_time, growth_opportunities = {})
    {
      symbol: symbol["symbol"],
      base_asset: symbol["baseAsset"],
      quote_asset: symbol["quoteAsset"],
      check_time: current_time.iso8601,
      growth_opportunities: growth_opportunities,
      details: {
        base_asset_precision: symbol["baseAssetPrecision"],
        quote_asset_precision: symbol["quoteAssetPrecision"],
        order_types: symbol["orderTypes"],
        iceberg_allowed: symbol["icebergAllowed"],
        filters: symbol["filters"]
      }
    }
  end

  def load_reference_pairs
    return [] unless File.exist?(@reference_file)

    begin
      JSON.parse(File.read(@reference_file))
    rescue => e
      Rails.logger.error "Erreur de lecture du fichier de référence: #{e.message}"
      []
    end
  end

  def update_reference_pairs(new_pairs)
    FileUtils.mkdir_p(@storage_path)
    File.write(@reference_file, JSON.pretty_generate(new_pairs))
  end

  def save_response_to_file(response)
    filename = "exchange_info_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    filepath = @storage_path.join(filename)

    FileUtils.mkdir_p(@storage_path)
    File.open(filepath, "w") do |file|
      file.write(JSON.pretty_generate({
        timestamp: Time.now.iso8601,
        data: response
      }))
    end
  end

  def save_new_listings(listings)
    return if listings.empty?

    filename = "new_listings_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    filepath = @storage_path.join(filename)

    FileUtils.mkdir_p(@storage_path)
    File.open(filepath, "w") do |file|
      file.write(JSON.pretty_generate({
        timestamp: Time.now.iso8601,
        listings: listings
      }))
    end

    Rails.logger.info "Nouvelles listes sauvegardées dans #{filepath}"
  end

  def send_notifications(listings)
    listings.each do |listing|
      message = format_notification_message(listing)
      send_telegram_message(message)
    end
  end

  def format_notification_message(listing)
    symbol = listing[:symbol]
    base_asset = listing[:base_asset]
    growth = listing[:growth_opportunities]

    message = "🚀 Nouvelle crypto-monnaie sur Binance!\n\n" \
              "Symbole: #{symbol}\n" \
              "Actif: #{base_asset}\n" \
              "Détecté à: #{Time.parse(listing[:check_time]).strftime('%H:%M:%S')}\n\n"

    # Vérifier que growth est une collection avant d'appeler any?
    if growth.is_a?(Hash) && growth.any?
      message += "Croissance:\n"
      growth.each do |period, percentage|
        message += "#{period}: #{percentage}%\n"
      end
      message += "\n"
    end

    message += "Voir le cours: https://www.binance.com/en/trade/#{symbol}\n" \
               "Précision: #{listing[:details][:base_asset_precision]} décimales"

    message
  end

  def send_telegram_message(message)
    return unless @telegram_bot_token && @telegram_chat_id

    begin
      response = HTTParty.post(
        "https://api.telegram.org/bot#{@telegram_bot_token}/sendMessage",
        body: {
          chat_id: @telegram_chat_id,
          text: message,
          parse_mode: "HTML"
        }
      )

      unless response.success?
        Rails.logger.error "Erreur d'envoi Telegram: #{response.body}"
      end
    rescue => e
      Rails.logger.error "Erreur d'envoi Telegram: #{e.message}"
    end
  end

  def adjust_indicators
    Rails.logger.info "Ajustement des indicateurs - Compteur sans résultats: #{@no_results_count}"
    Rails.logger.info "Seuils actuels: #{@indicators}"

    # Réduire progressivement les seuils
    @indicators[:volume_spike_multiplier] = [ @indicators[:volume_spike_multiplier] * 0.9, MIN_INDICATORS[:volume_spike_multiplier] ].max
    @indicators[:rsi_threshold] = [ @indicators[:rsi_threshold] - 2, MIN_INDICATORS[:rsi_threshold] ].max
    @indicators[:upper_wick_percentage] = [ @indicators[:upper_wick_percentage] + 0.2, MIN_INDICATORS[:upper_wick_percentage] ].min

    Rails.logger.info "Nouveaux seuils après ajustement: #{@indicators}"

    # Relancer une vérification avec les nouveaux seuils
    sleep(1) # Petit délai pour éviter de surcharger l'API
    check_new_listings
  end

  def reset_indicators
    @indicators = BASE_INDICATORS.dup
    @no_results_count = 0
    Rails.logger.info "Réinitialisation des indicateurs aux valeurs de base"
  end

  def fetch_exchange_info
    cached_info = @cache.read(EXCHANGE_INFO_CACHE_KEY)
    return cached_info if cached_info

    response = self.class.get("/api/v3/exchangeInfo")
    return unless response.success?

    @cache.write(EXCHANGE_INFO_CACHE_KEY, response, expires_in: CACHE_EXPIRY)
    response
  end

  def handle_listings_result(new_listings)
    if new_listings.empty?
      @no_results_count += 1
      if @no_results_count >= 3
        Rails.logger.info "Aucun résultat trouvé après #{@no_results_count} tentatives, ajustement des seuils..."
        adjust_indicators
      end
    else
      Rails.logger.info "Résultats trouvés avec les seuils actuels: #{@indicators}"
      @no_results_count = 0
      reset_indicators
      save_new_listings(new_listings)
      send_notifications(new_listings)
    end
  end

  def log_ai_analysis(analysis)
    Rails.logger.info "  - Score de confiance: #{analysis[:confidence_score]}"
    Rails.logger.info "  - Force de la tendance: #{analysis[:analysis][:trend_strength]}"
    Rails.logger.info "  - Reconnaissance de pattern: #{analysis[:analysis][:pattern_recognition]}"
    Rails.logger.info "  - Analyse du volume: #{analysis[:analysis][:volume_analysis]}"
    Rails.logger.info "  - Évaluation du risque: #{analysis[:analysis][:risk_assessment]}"
    Rails.logger.info "  - Recommandations: #{analysis[:analysis][:recommendations]}"
    Rails.logger.info "  - Provider: #{analysis[:provider]}"
  end
end
