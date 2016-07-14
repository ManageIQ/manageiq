class AddStatusToMiddlewareDeployments < ActiveRecord::Migration[5.0]
  def change
    add_column :middleware_deployments, :status, :string
  end
end
