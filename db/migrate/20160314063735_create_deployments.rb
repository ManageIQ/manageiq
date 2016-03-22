class CreateDeployments < ActiveRecord::Migration[5.0]
  def change
    create_table :deployments do |t|
      t.string   :deployment_type

      # provider (optional)
      # vms - masters/nodes (optional)
      # vms-notmanaged - ip (optional)
      # current state (required)
      # total time (required)
      # automation task
      # last error (required)
      t.timestamps
    end
  end
end
