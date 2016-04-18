class SetCorrectStiTypeOnCloudNetwork < ActiveRecord::Migration
  CLOUD_TEMPLATE_CLASS = "ManageIQ::Providers::Openstack::CloudManager::Template".freeze
  CLOUD_PUBLIC_CLASS   = "ManageIQ::Providers::Openstack::CloudManager::CloudNetwork::Public".freeze
  CLOUD_PRIVATE_CLASS  = "ManageIQ::Providers::Openstack::CloudManager::CloudNetwork::Private".freeze

  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class BaseManager < ExtManagementSystem; end

  class CloudManager < BaseManager; end

  class CloudNetwork < ActiveRecord::Base
    self.inheritance_column = :_type_disabled

    belongs_to :ext_management_system,
               :foreign_key => :ems_id, :class_name => SetCorrectStiTypeOnCloudNetwork::BaseManager
  end

  def up
    CloudNetwork.update_all(:type => CLOUD_TEMPLATE_CLASS)

    CloudNetwork.joins(:ext_management_system)
                .where(:cloud_networks => {:external_facing => true},
                       :ext_management_systems => {:type => 'ManageIQ::Providers::Openstack::CloudManager'})
                .update_all(:type => CLOUD_PUBLIC_CLASS)

    CloudNetwork.joins(:ext_management_system)
                .where.not(:cloud_networks => {:external_facing => true})
                .where(:ext_management_systems => {:type => 'ManageIQ::Providers::Openstack::InfraManager'})
                .update_all(:type => CLOUD_PRIVATE_CLASS)
  end

  def down
    CloudNetwork.update_all(:type => nil)
  end
end
