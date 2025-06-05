class GrowthOpportunitiesController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @opportunities = GrowthOpportunity.order(created_at: :desc)
  end
  
  def refresh
    GrowthOpportunitiesJob.perform_inline
    redirect_to growth_opportunities_path, notice: "Les opportunités ont été actualisées avec succès."
  end
end 