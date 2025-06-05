class TradingRecommendationsController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @recommendations = TradingRecommendation.order(timestamp: :desc)
    @symbols = TradingRecommendation.select(:symbol).distinct.order(:symbol).pluck(:symbol)
    
    if params[:symbol].present?
      @recommendations = @recommendations.where(symbol: params[:symbol])
    end
    
    @recommendations = @recommendations.paginate(page: params[:page], per_page: 20)
  end
  
  def refresh
    TradingAnalysisJob.perform_now
    redirect_to trading_recommendations_path, notice: "Analyse des recommandations en cours..."
  end
end 