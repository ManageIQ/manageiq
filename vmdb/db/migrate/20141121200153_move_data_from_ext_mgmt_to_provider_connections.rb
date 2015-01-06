class MoveDataFromExtMgmtToProviderConnections < ActiveRecord::Migration
  def up
    ExtManagementSystem.find_each do |ext|
      conn = ext.provider_connections.create(
        :ems_id    => ext[:id],
        :port      => ext[:port],
        :hostname  => ext[:hostname],
        :ipaddress => ext[:ipaddress]
      )
      Authentication.where(:resource_id => ext.id).find_each do |auth|
        auth.update_attributes(
          :resource_type => conn.class.name,
          :name          => "#{conn.class.name}/#{conn.id}",
          :resource_id   => conn.id
        )
      end
    end
  end

  def down
    ProviderConnection.find_each do |conn|
      ems = ExtManagementSystem.where(:id => conn.ems_id).first

      execute "update ext_management_systems set port ='#{conn.port}',
        ipaddress='#{conn.ipaddress}', hostname ='#{conn.hostname}' where id=#{conn.ems_id}"

      Authentication.where(:resource_id => conn.id).find_each do |auth|
        auth.update_attributes(
          :resource_type => 'ExtManagementSystem',
          :name          => ems.name,
          :resource_id   => ems.id
        )
      end

      conn.destroy
    end
  end
end
