class SchedulerService
  def self.schedule_trading_analysis
    Sidekiq.schedule = {
      trading_analysis: {
        cron: '*/5 * * * *',
        class: 'TradingAnalysisJob',
        queue: 'trading',
        description: 'Analyse périodique des opportunités de trading',
        enabled: true,
        args: -> { TradingConfig.active.pluck(:id) }
      }
    }
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end 