class CreateProviderConnections < ActiveRecord::Migration
  def change
    create_table :provider_connections do |t|
      t.string :port
      t.bigint :ems_id
      t.string :ipaddress
      t.string :hostname
      t.string :name
      t.string :provider_component

      t.timestamps
    end
  end
end
