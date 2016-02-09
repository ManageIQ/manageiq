class SetCorrectStiTypeOnOpenstackCloudVolume < ActiveRecord::Migration
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class CloudVolume < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    # Set OpenStack Infra specific STI types for miq_template under that provider
    CloudVolume.joins('join ext_management_systems on cloud_volumes.ems_id = ext_management_systems.id')
      .where(:cloud_volumes          => {:type => nil},
             :ext_management_systems => {:type => 'ManageIQ::Providers::Openstack::CloudManager'})
      .update_all("type = 'ManageIQ::Providers::Openstack::CloudManager::CloudVolume'")
  end

  def down
    # Set back Openstack cloud specific STI types for miq_template under infra that provider
    CloudVolume.joins('join ext_management_systems on cloud_volumes.ems_id = ext_management_systems.id')
      .where(:cloud_volumes          => {:type => 'ManageIQ::Providers::Openstack::CloudManager::CloudVolume'},
             :ext_management_systems => {:type => 'ManageIQ::Providers::Openstack::CloudManager'})
      .update_all("type = NULL")
  end
end
