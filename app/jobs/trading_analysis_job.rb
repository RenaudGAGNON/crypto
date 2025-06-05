class TradingAnalysisJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting TradingAnalysisJob"
    
    begin
      # Liste des symboles à analyser
      symbols = %w[BTCUSDT ETHUSDT BNBUSDT ADAUSDT SOLUSDT]
      
      symbols.each do |symbol|
        begin
          Rails.logger.info "Analyzing #{symbol}"
          
          Rails.logger.info "Successfully analyzed #{symbol}"
        rescue => e
          Rails.logger.error "Error analyzing #{symbol}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    rescue => e
      Rails.logger.error "Error in TradingAnalysisJob: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
    
    Rails.logger.info "Completed TradingAnalysisJob"
  end

end