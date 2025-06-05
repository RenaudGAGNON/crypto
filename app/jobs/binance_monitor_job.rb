class BinanceMonitorJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "=== Démarrage de BinanceMonitorJob ==="
    Rails.logger.info "Heure: #{Time.current}"

    monitor = BinanceMonitorService.new
    Rails.logger.info "Service initialisé"

    begin
      new_listings = monitor.check_new_listings
      if new_listings&.any?
        Rails.logger.info "Nouvelles listes trouvées: #{new_listings.map { |l| l[:symbol] }.join(', ')}"
      else
        Rails.logger.info "Aucune nouvelle liste trouvée"
      end
    rescue => e
      Rails.logger.error "Erreur dans BinanceMonitorJob: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    Rails.logger.info "=== Fin de BinanceMonitorJob ==="
  end
end
