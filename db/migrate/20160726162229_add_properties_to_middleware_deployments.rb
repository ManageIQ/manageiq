class AddPropertiesToMiddlewareDeployments < ActiveRecord::Migration[5.0]
  def change
    add_column :middleware_deployments, :properties, :text
  end
end
