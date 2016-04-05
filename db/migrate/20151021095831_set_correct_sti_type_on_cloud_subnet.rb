class SetCorrectStiTypeOnCloudSubnet < ActiveRecord::Migration
  CLOUD_SUBNET         = "ManageIQ::Providers::Openstack::CloudManager::CloudSubnet".freeze
  CLOUD_PUBLIC_CLASS   = "ManageIQ::Providers::Openstack::CloudManager::CloudNetwork::Public".freeze
  CLOUD_PRIVATE_CLASS  = "ManageIQ::Providers::Openstack::CloudManager::CloudNetwork::Private".freeze

  class CloudNetwork < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class CloudSubnet < ActiveRecord::Base
    self.inheritance_column = :_type_disabled

    belongs_to :cloud_network
  end

  def up
    CloudSubnet.update_all(:type => "CloudSubnet")

    CloudSubnet.joins(:cloud_network).where(:cloud_networks => {:type => [CLOUD_PUBLIC_CLASS, CLOUD_PRIVATE_CLASS]})
               .update_all(:type => CLOUD_SUBNET)
  end

  def down
    CloudSubnet.update_all(:type => nil)
  end
end
