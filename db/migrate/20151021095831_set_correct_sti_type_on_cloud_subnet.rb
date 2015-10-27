class SetCorrectStiTypeOnCloudSubnet < ActiveRecord::Migration
  def up
    connection.execute <<-SQL
      UPDATE cloud_subnets
      SET type = 'CloudSubnet'
    SQL

    # Set OpenStack specific STI types
    connection.execute <<-SQL
      UPDATE cloud_subnets s
      SET type = 'ManageIQ::Providers::Openstack::CloudManager::CloudSubnet'
      FROM cloud_networks n
      WHERE s.cloud_network_id = n.id AND ( n.type = 'ManageIQ::Providers::Openstack::CloudManager::CloudNetwork::Private' OR
                                            n.type = 'ManageIQ::Providers::Openstack::CloudManager::CloudNetwork::Public')
    SQL
  end

  def down
    connection.execute <<-SQL
      UPDATE cloud_subnets
      SET type = NULL
    SQL
  end
end
