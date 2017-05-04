class AddNodePort < ActiveRecord::Migration[4.2]
  def change
    add_column :container_service_port_configs, :node_port, :integer
  end
end
