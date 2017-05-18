class AddServerGroupIdToMiddlewareDeployments < ActiveRecord::Migration[5.0]
  def change
    add_column :middleware_deployments, :server_group_id, :bigint
  end
end
