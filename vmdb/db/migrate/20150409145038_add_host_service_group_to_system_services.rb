class AddHostServiceGroupToSystemServices < ActiveRecord::Migration
  def change
    add_column :system_services, :host_service_group_id, :bigint
    add_index :system_services, :host_service_group_id
  end
end
