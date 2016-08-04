class AddServerGroupIdToMiddlewareServers < ActiveRecord::Migration[5.0]
  def change
    add_column :middleware_servers, :server_group_id, :bigint
  end
end
