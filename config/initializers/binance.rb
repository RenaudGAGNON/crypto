# Configuration Binance
Rails.application.config.binance = {
  api_key: ENV['BINANCE_API_KEY'],
  api_secret: ENV['BINANCE_API_SECRET'],
  testnet: ENV['BINANCE_TESTNET'] == 'true',
  telegram_bot_token: ENV['TELEGRAM_BOT_TOKEN'],
  telegram_chat_id: ENV['TELEGRAM_CHAT_ID']
}

# Vérification des variables d'environnement requises
required_env_vars = %w[BINANCE_API_KEY BINANCE_API_SECRET TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID]
missing_vars = required_env_vars.select { |var| ENV[var].blank? }

if missing_vars.any?
  Rails.logger.error "Variables d'environnement manquantes pour Binance: #{missing_vars.join(', ')}"
  raise "Variables d'environnement manquantes pour Binance: #{missing_vars.join(', ')}"
end 