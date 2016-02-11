class AddServiceOrderToMiqRequest < ActiveRecord::Migration
  def change
    add_column :miq_requests, :service_order_id, :bigint
  end
end
