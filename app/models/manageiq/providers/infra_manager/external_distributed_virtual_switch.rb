class ManageIQ::Providers::InfraManager::ExternalDistributedVirtualSwitch < ::Switch
  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :external_distributed_virtual_switches, :class_name => "ManageIQ::Providers::InfraManager"
end
