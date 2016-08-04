class AddFeedToMiddlewareDeploymentsAndDatasources < ActiveRecord::Migration[5.0]
  def change
    add_column :middleware_deployments, :feed, :string
    add_column :middleware_datasources, :feed, :string
  end
end
