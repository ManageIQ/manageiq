class CreateServiceOrders < ActiveRecord::Migration[4.2]
  def change
    create_table :service_orders do |t|
      t.string   :name
      t.bigint   :tenant_id
      t.bigint   :user_id
      t.string   :user_name
      t.string   :state
      t.datetime :created_at
      t.datetime :updated_at
      t.datetime :placed_at
    end
  end
end
