class DryTradingExecutorService
  def initialize
    @trading_service = BinanceTradingService.new(dry_run: true)
    Rails.logger.info("Initialisation du DryTradingExecutorService")
  end

  def execute_pending_orders
    Rails.logger.info("Recherche des positions ouvertes en mode DRY")
    # Récupérer les positions ouvertes en mode DRY
    positions = TradingPosition.where(dry_run: true, status: 'open')
                              .includes(:trades)

    Rails.logger.info("Nombre de positions trouvées : #{positions.count}")

    positions.each do |position|
      begin
        Rails.logger.info("Traitement de la position #{position.id} pour #{position.symbol}")
        execute_position_orders(position)
      rescue StandardError => e
        Rails.logger.error("Erreur lors de l'exécution des ordres pour la position #{position.id}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end
  end

  private

  def execute_position_orders(position)
    current_price = fetch_current_price(position.symbol)
    unless current_price
      Rails.logger.warn("Impossible de récupérer le prix pour #{position.symbol}")
      return
    end

    Rails.logger.info("Prix actuel pour #{position.symbol}: #{current_price}")

    # Vérifier les niveaux de take profit
    check_take_profit_levels(position, current_price)
    
    # Vérifier le stop loss
    check_stop_loss(position, current_price)
  end

  def check_take_profit_levels(position, current_price)
    Rails.logger.info("Vérification des niveaux de take profit pour #{position.symbol}")
    position.take_profit_levels.each do |level|
      next if level['status'] == 'executed'
      
      target_price = level['price'].to_f
      Rails.logger.info("Niveau #{level['percentage']}% - Prix cible: #{target_price}, Prix actuel: #{current_price}")
      
      if current_price >= target_price
        Rails.logger.info("Niveau de take profit atteint pour #{position.symbol} à #{level['percentage']}%")
        execute_take_profit(position, level, current_price)
      end
    end
  end

  def check_stop_loss(position, current_price)
    Rails.logger.info("Vérification du stop loss pour #{position.symbol} - Prix actuel: #{current_price}, Stop loss: #{position.stop_loss}")
    if current_price <= position.stop_loss
      Rails.logger.info("Stop loss atteint pour #{position.symbol}")
      execute_stop_loss(position, current_price)
    end
  end

  def execute_take_profit(position, level, current_price)
    Rails.logger.info("Exécution du take profit pour #{position.symbol} à #{level['percentage']}%")
    # Calculer la quantité à vendre (25% de la position totale)
    quantity = (position.quantity * 0.25).round(8)

    # Créer l'ordre de vente
    order = @trading_service.create_order(
      symbol: position.symbol,
      side: 'SELL',
      type: 'MARKET',
      quantity: quantity
    )

    if order
      Rails.logger.info("Ordre de take profit exécuté avec succès pour #{position.symbol}")
      # Mettre à jour le statut du niveau
      level['status'] = 'executed'
      level['executed_at'] = Time.current
      level['executed_price'] = current_price
      position.save

      # Créer le trade
      position.trades.create!(
        type: 'exit',
        price: current_price,
        quantity: quantity,
        status: 'executed',
        binance_order_id: order['orderId'],
        executed_at: Time.current,
        metadata: {
          take_profit_level: level['percentage'],
          reason: 'take_profit'
        }
      )

      # Vérifier si tous les niveaux sont exécutés
      check_position_completion(position)
    else
      Rails.logger.error("Échec de l'exécution de l'ordre de take profit pour #{position.symbol}")
    end
  end

  def execute_stop_loss(position, current_price)
    Rails.logger.info("Exécution du stop loss pour #{position.symbol}")
    # Vendre toute la position restante
    order = @trading_service.create_order(
      symbol: position.symbol,
      side: 'SELL',
      type: 'MARKET',
      quantity: position.quantity
    )

    if order
      Rails.logger.info("Ordre de stop loss exécuté avec succès pour #{position.symbol}")
      # Créer le trade
      position.trades.create!(
        type: 'exit',
        price: current_price,
        quantity: position.quantity,
        status: 'executed',
        binance_order_id: order['orderId'],
        executed_at: Time.current,
        metadata: {
          reason: 'stop_loss'
        }
      )

      # Fermer la position
      position.update!(status: 'closed')
    else
      Rails.logger.error("Échec de l'exécution de l'ordre de stop loss pour #{position.symbol}")
    end
  end

  def check_position_completion(position)
    # Vérifier si tous les niveaux de take profit sont exécutés
    all_levels_executed = position.take_profit_levels.all? { |level| level['status'] == 'executed' }
    
    if all_levels_executed
      Rails.logger.info("Tous les niveaux de take profit sont exécutés pour #{position.symbol}, fermeture de la position")
      position.update!(status: 'closed')
    end
  end

  def fetch_current_price(symbol)
    Rails.logger.info("Récupération du prix actuel pour #{symbol}")
    response = HTTParty.get("#{@trading_service.class.base_uri}/api/v3/ticker/price", {
      query: { symbol: symbol }
    })

    return nil unless response.success?
    price = JSON.parse(response.body)['price'].to_f
    Rails.logger.info("Prix récupéré pour #{symbol}: #{price}")
    price
  rescue StandardError => e
    Rails.logger.error("Erreur lors de la récupération du prix pour #{symbol}: #{e.message}")
    nil
  end
end 