class AddMiddlewareServerEventStreams < ActiveRecord::Migration[5.0]
  def change
    add_column :event_streams, :middleware_server_id, :bigint
    add_column :event_streams, :middleware_server_name, :string
    add_column :event_streams, :middleware_deployment_id, :bigint
    add_column :event_streams, :middleware_deployment_name, :string
  end
end
