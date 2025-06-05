# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Créer un utilisateur par défaut
user = User.create!(
  email: 'admin@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

# Créer une configuration de trading par défaut
TradingConfig.create!(
  user: user,
  api_key: 'dummy_key',
  api_secret: 'dummy_secret',
  mode: 'live',
  check_interval: 300,
  min_growth_rate: 5.0,
  max_investment_per_trade: 100.0,
  active: true,
  status: 'active',
  volume_spike_multiplier: 2.5,
  rsi_threshold: 65.0,
  upper_wick_percentage: 2.0
)
