class CreateContainerDeploymentNodes < ActiveRecord::Migration[5.0]
  def change
    create_table :container_deployment_nodes do |t|
      t.string     :address
      t.string     :name
      t.text       :labels
      t.belongs_to :container_deployment, :type => :bigint
      t.belongs_to :vm, :type => :bigint
      t.text       :docker_storage_devices, :array => true, :default => []
      t.bigint     :docker_storage_data_size
      t.text       :customizations
      t.timestamps
    end
  end
end
