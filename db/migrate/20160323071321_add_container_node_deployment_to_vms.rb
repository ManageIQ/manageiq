class AddContainerNodeDeploymentToVms < ActiveRecord::Migration[5.0]
  def change
    add_reference :vms, :container_node_deployment, foreign_key: true
  end
end
