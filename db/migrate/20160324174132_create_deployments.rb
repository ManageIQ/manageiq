class CreateDeployments < ActiveRecord::Migration[5.0]
  def change
    create_table :container_deployments do |t|
      t.string   :deployment_type
      t.string   :deployment_version
      t.boolean  :containerized, :default => true
      t.string   :deployment_method
      t.string   :deployed_provider_type
      t.string   :deployed_provider_name
      t.string   :ssh_private
      t.string   :ssh_public
      t.string   :ssh_user
      t.string   :rhsm_user
      t.string   :rhsm_pass
      t.string   :rhsm_sku
      t.string   :rhsm_pool_id
      t.string   :persistent_storage_type
      t.references :miq_request_task
      t.integer :deployed_ext_management_system_id, :integer
      t.integer :deployed_on_ext_management_system_id, :integer
      t.timestamps
    end
  end
end
