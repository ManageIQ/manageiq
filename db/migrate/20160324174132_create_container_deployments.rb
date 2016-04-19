class CreateContainerDeployments < ActiveRecord::Migration[5.0]
  def change
    create_table :container_deployments do |t|
      t.string     :kind
      t.string     :version
      t.boolean    :containerized
      t.string     :method_type
      t.string     :metrics_endpoint
      t.text       :customizations
      t.boolean    :deploy_metrics
      t.boolean    :deploy_registry
      t.belongs_to :automation_task, :type => :bigint
      t.belongs_to :deployed_ems,    :type => :bigint
      t.belongs_to :deployed_on_ems, :type => :bigint
      t.timestamps
    end
  end
end
