class MarketMoversController < ApplicationController
  before_action :authenticate_user!

  def index
    @top_movers = AlphaVantageService.new.get_top_movers
  end

  def refresh
    @top_movers = AlphaVantageService.new.get_top_movers
    
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to market_movers_path }
    end
  end
end 