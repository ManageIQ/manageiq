class ManageIQ::Providers::InfraManager::DistributedVirtualSwitch < ::Switch
  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :distributed_virtual_switch
end
