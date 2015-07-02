class AddContainerProjectRelationship < ActiveRecord::Migration
  def change
    add_column :container_groups, :container_project_id, :bigint
    add_column :container_routes, :container_project_id, :bigint
    add_column :container_services, :container_project_id, :bigint
    add_column :container_replicators, :container_project_id, :bigint
    remove_column :container_groups, :namespace, :string
    remove_column :container_services, :namespace, :string
    remove_column :container_replicators, :namespace, :string
    remove_column :container_routes, :namespace, :string
  end
end
