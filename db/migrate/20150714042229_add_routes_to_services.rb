class AddRoutesToServices < ActiveRecord::Migration
  def change
    add_column :container_routes, :container_service_id, :bigint
    remove_column :container_routes, :service_name, :string
  end
end
