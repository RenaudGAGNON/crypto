class DryTradingExecutorJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("Démarrage de l'exécution des ordres en mode DRY")
    service = DryTradingExecutorService.new
    service.execute_pending_orders
    Rails.logger.info("Fin de l'exécution des ordres en mode DRY")
  rescue StandardError => e
    Rails.logger.error("Erreur dans DryTradingExecutorJob: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end
end 