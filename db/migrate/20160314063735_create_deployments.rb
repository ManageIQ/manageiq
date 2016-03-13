class CreateDeployments < ActiveRecord::Migration[5.0]
  def change
    create_table :deployments do |t|
      t.string   :deployment_type
      t.string   :deployed_provider_type
      t.string   :deployed_provider_name
      t.string   :ssh_private
      t.string   :ssh_public
      t.string   :ssh_user
      t.string   :auth_type #create table
      t.string   :persistent_storage_type
      t.references :automation_task
      t.references :ext_management_system
      t.timestamps
    end
  end
end
