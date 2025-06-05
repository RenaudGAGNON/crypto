class GrowthOpportunitiesJob
  include Sidekiq::Job
  require 'binance'
  sidekiq_options queue: :trading, retry: 3, backtrace: true
  
  def perform
    begin
      # Récupérer les données de tous les symboles
      client = Binance::Spot.new(key: ENV['BINANCE_API_KEY'], secret: ENV['BINANCE_API_SECRET'])
      tickers = client.ticker_24hr

      # Filtrer et trier les opportunités
      opportunities = tickers
        .select { |ticker| ticker[:symbol].end_with?('USDT') }
        .map do |ticker|
          {
            symbol: ticker[:symbol],
            price: ticker[:lastPrice].to_f,
            volume_24h: ticker[:volume].to_f,
            price_change_24h: ticker[:priceChangePercent].to_f,
            market_cap: ticker[:quoteVolume].to_f
          }
        end
        .sort_by { |opp| -opp[:price_change_24h] }
        .first(20)
      
      # Enregistrer les opportunités
      opportunities.each do |opp|
        GrowthOpportunity.create!(
          symbol: opp[:symbol],
          price: opp[:price],
          volume_24h: opp[:volume_24h],
          price_change_24h: opp[:price_change_24h],
          market_cap: opp[:market_cap]
        )
      end
      
      Rails.logger.info "Opportunités de croissance mises à jour avec succès"
    rescue StandardError => e
      Rails.logger.error "Erreur lors de la récupération des opportunités: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end 