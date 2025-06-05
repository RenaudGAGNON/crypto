class VoucherOrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_voucher_order, only: [ :show, :edit, :update, :destroy ]

  def index
    @voucher_orders = VoucherOrder.recent.page(params[:page])
    @stats = calculate_stats
  end

  def show
  end

  def new
    @voucher_order = VoucherOrder.new
  end

  def edit
  end

  def create
    @voucher_order = VoucherOrder.new(voucher_order_params)

    if @voucher_order.save
      redirect_to @voucher_order, notice: "La commande a été créée avec succès."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @voucher_order.update(voucher_order_params)
      redirect_to @voucher_order, notice: "La commande a été mise à jour avec succès."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @voucher_order.destroy
    redirect_to voucher_orders_url, notice: "La commande a été supprimée avec succès."
  end

  private

  def set_voucher_order
    @voucher_order = VoucherOrder.find(params[:id])
  end

  def voucher_order_params
    params.require(:voucher_order).permit(:symbol, :amount, :price, :status, :order_id, :metadata)
  end

  def calculate_stats
    {
      total_orders: VoucherOrder.count,
      executed_orders: VoucherOrder.executed.count,
      pending_orders: VoucherOrder.pending.count,
      total_profit: VoucherOrder.sum(:profit_loss),
      average_profit: VoucherOrder.average(:profit_loss)&.round(2) || 0
    }
  end
end
