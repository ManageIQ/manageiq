class SetCorrectStiTypeOnCloudNetwork < ActiveRecord::Migration
  def up
    connection.execute <<-SQL
      UPDATE cloud_networks
      SET type = 'CloudNetwork'
    SQL

    # Set OpenStack specific STI types for Public network
    connection.execute <<-SQL
      UPDATE cloud_networks c
      SET type = 'ManageIQ::Providers::Openstack::CloudManager::CloudNetwork::Public'
      FROM ext_management_systems e
      WHERE c.ems_id = e.id AND c.external_facing AND e.type = 'ManageIQ::Providers::Openstack::CloudManager'
    SQL

    # Set OpenStack specific STI types for Private network
    connection.execute <<-SQL
      UPDATE cloud_networks c
      SET type = 'ManageIQ::Providers::Openstack::CloudManager::CloudNetwork::Private'
      FROM ext_management_systems e
      WHERE c.ems_id = e.id AND NOT c.external_facing AND e.type = 'ManageIQ::Providers::Openstack::CloudManager'
    SQL
  end

  def down
    connection.execute <<-SQL
      UPDATE cloud_networks
      SET type = NULL
    SQL
  end
end
