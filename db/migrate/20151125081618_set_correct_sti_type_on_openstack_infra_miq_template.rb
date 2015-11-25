class SetCorrectStiTypeOnOpenstackInfraMiqTemplate < ActiveRecord::Migration
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class Vm < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    # Set OpenStack Infra specific STI types for miq_template under that provider
    connection.execute <<-SQL
      UPDATE vms v
      SET type = 'ManageIQ::Providers::Openstack::InfraManager::Template'
      FROM ext_management_systems e
      WHERE v.ems_id = e.id AND v.type = 'ManageIQ::Providers::Openstack::CloudManager::Template' AND
            e.type = 'ManageIQ::Providers::Openstack::InfraManager'
    SQL
  end

  def down
    # Set back Openstack cloud specific STI types for miq_template under infra that provider
    connection.execute <<-SQL
      UPDATE vms v
      SET type = 'ManageIQ::Providers::Openstack::CloudManager::Template'
      FROM ext_management_systems e
      WHERE v.ems_id = e.id AND v.type = 'ManageIQ::Providers::Openstack::InfraManager::Template' AND
            e.type = 'ManageIQ::Providers::Openstack::InfraManager'
    SQL
  end
end
