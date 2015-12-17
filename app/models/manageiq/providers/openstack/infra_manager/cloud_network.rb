class ManageIQ::Providers::Openstack::InfraManager::CloudNetwork < ::CloudNetwork
  require_nested :Private
  require_nested :Public

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::InfraManager"
end
