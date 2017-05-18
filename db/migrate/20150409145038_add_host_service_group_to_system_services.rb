class AddHostServiceGroupToSystemServices < ActiveRecord::Migration[4.2]
  def change
    add_column :system_services, :host_service_group_id, :bigint
    add_index :system_services, :host_service_group_id
  end
end
