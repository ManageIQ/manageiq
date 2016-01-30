class AddNodePort < ActiveRecord::Migration
  def change
    add_column :container_service_port_configs, :node_port, :integer
  end
end
