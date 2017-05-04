class AddServiceOrderToMiqRequest < ActiveRecord::Migration[4.2]
  def change
    add_column :miq_requests, :service_order_id, :bigint
  end
end
