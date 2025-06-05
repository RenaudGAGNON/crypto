class TradesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trade, only: [:show]

  def index
    @trades = current_user.trades.order(created_at: :desc)
  end

  def show
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Le trade demandé n'existe pas."
    redirect_to trades_path
  end

  private

  def set_trade
    @trade = current_user.trades.find(params[:id])
  end
end 