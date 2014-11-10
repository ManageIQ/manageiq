class AddProviderComponentToEmsConnections < ActiveRecord::Migration
  def change
    add_column :ems_connections, :provider_component, :string
  end
end
