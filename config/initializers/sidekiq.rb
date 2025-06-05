require 'sidekiq'
require 'sidekiq/web'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
  
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq_scheduler.yml', __FILE__))
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end

  config.logger = Logger.new(Rails.root.join('log', 'sidekiq.log'))
  config.logger.level = Logger::INFO
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end

# Configuration des queues
Sidekiq.configure_server do |config|
  config.queues = %w[default trading]
end

# Configuration des options de Sidekiq
Sidekiq.default_job_options = {
  retry: 3,
  backtrace: true,
  queue: 'default'
}

# Configuration de l'interface web
Sidekiq::Web.class_eval do
  use Rack::Protection, origin_whitelist: ['http://localhost:3000'] # Permet les requêtes depuis localhost
end 