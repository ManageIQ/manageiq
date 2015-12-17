class ManageIQ::Providers::Openstack::InfraManager::NetworkPort < ::NetworkPort
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::InfraManager"
end
