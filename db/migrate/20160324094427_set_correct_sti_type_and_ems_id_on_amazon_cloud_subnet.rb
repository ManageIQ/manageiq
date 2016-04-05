class SetCorrectStiTypeAndEmsIdOnAmazonCloudSubnet < ActiveRecord::Migration[5.0]
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class CloudNetwork < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class CloudSubnet < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    # Fill a missing link of CloudSubnet to EMS and a correct STI
    ExtManagementSystem
      .where({:type => 'ManageIQ::Providers::Amazon::NetworkManager'}).each do |ems|
      CloudSubnet
        .joins('left join cloud_networks on cloud_networks.id = cloud_subnets.cloud_network_id')
        .where(:cloud_subnets  => {:type   => nil},
               :cloud_networks => {:ems_id => ems.id})
        .update_all("type = 'ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet', ems_id = '#{ems.id}'")
    end
  end

  def down
    # Connect CloudSubnet back to CloudManager
    CloudSubnet
      .joins('left join cloud_networks on cloud_networks.id = cloud_subnets.cloud_network_id')
      .joins('left join ext_management_systems on ext_management_systems.id = cloud_networks.ems_id')
      .joins('left join ext_management_systems as cloud_manager on ext_management_systems.parent_ems_id = cloud_manager.id')
      .where(:cloud_subnets => {:type => 'ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet'},
             :cloud_manager => {:type => 'ManageIQ::Providers::Amazon::CloudManager'})
      .update_all("type = NULL")
  end
end
