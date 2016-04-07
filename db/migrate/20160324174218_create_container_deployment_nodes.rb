class CreateContainerDeploymentNodes < ActiveRecord::Migration[5.0]
  def change
    create_table :container_deployment_nodes do |t|
      t.string :ip_or_hostname
      t.string :name
      t.text :labels
      t.references :container_deployment
      t.references :vm
      t.timestamps
    end
  end
end
