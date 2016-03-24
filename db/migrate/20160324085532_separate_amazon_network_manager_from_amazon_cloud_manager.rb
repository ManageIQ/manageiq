class SeparateAmazonNetworkManagerFromAmazonCloudManager < ActiveRecord::Migration[5.0]
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class CloudNetwork < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class CloudSubnet < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class NetworkPort < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class NetworkRouter < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class FloatingIp < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class SecurityGroup < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def affected_classes
    [CloudNetwork, CloudSubnet, NetworkPort, NetworkRouter, FloatingIp, SecurityGroup]
  end

  def up
    # Separate NetworkManager from CloudManager and move network models under NetworkManager
    ExtManagementSystem
      .joins('left join ext_management_systems as network_manager on network_manager.parent_ems_id = ext_management_systems.id')
      .where(:ext_management_systems => {:type          => 'ManageIQ::Providers::Amazon::CloudManager'},
             :network_manager        => {:parent_ems_id => nil}).each do |cloud_manager|
      network_manager = ExtManagementSystem.create!(
        :type          => 'ManageIQ::Providers::Amazon::NetworkManager',
        :name          => "#{cloud_manager.name} Network Manager",
        :parent_ems_id => cloud_manager.id,
        :guid          => MiqUUID.new_guid)

      affected_classes.each do |network_model_class|
        network_model_class
          .where(:ems_id => cloud_manager.id)
          .update_all("type = 'ManageIQ::Providers::Amazon::NetworkManager::#{network_model_class.name.demodulize}', ems_id = '#{network_manager.id}'")
      end
    end
  end

  def down
    # Move NetworkManager models back from CloudManager and delete NetworkManager
    ExtManagementSystem
      .joins('join ext_management_systems as network_manager on network_manager.parent_ems_id = ext_management_systems.id')
      .where(:ext_management_systems => {:type => 'ManageIQ::Providers::Amazon::CloudManager'}).each do |cloud_manager|

      network_manager = ExtManagementSystem.where(:parent_ems_id => cloud_manager.id).first
      affected_classes.each do |network_model_class|
        network_model_class
          .where(:ems_id => network_manager.id)
          .update_all("type = 'ManageIQ::Providers::Amazon::CloudManager::#{network_model_class.name.demodulize}', ems_id = '#{cloud_manager.id}'")
      end

      network_manager.destroy
    end
  end
end
