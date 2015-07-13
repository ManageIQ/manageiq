class AddContainerEvents < ActiveRecord::Migration
  def change
    add_column  :ems_events, :container_node_id, :bigint
    add_column  :ems_events, :container_node_name, :string
    add_column  :ems_events, :container_group_id, :bigint
    add_column  :ems_events, :container_group_name, :string
    add_column  :ems_events, :container_namespace, :string
  end
end
