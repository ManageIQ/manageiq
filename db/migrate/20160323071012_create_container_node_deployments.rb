class CreateContainerNodeDeployments < ActiveRecord::Migration[5.0]
  def change
    create_table :container_node_deployments do |t|
      t.string :ip
      t.string :name
      t.string :classification
      t.references :deployment
      t.timestamps
    end
  end
end
