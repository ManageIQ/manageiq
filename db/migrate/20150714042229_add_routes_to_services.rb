class AddRoutesToServices < ActiveRecord::Migration[4.2]
  def change
    add_column :container_routes, :container_service_id, :bigint
    remove_column :container_routes, :service_name, :string
  end
end
