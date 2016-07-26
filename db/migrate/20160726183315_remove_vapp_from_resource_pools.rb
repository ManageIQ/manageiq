class RemoveVappFromResourcePools < ActiveRecord::Migration[5.0]
  VMWARE_INFRA_VAPP_CLASS = 'ManageIQ::Providers::Vmware::InfraManager::VirtualApp'.freeze
  class ResourcePool < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    ResourcePool.where(:vapp => true).update_all(:type => VMWARE_INFRA_VAPP_CLASS)
    remove_column :resource_pools, :vapp
  end

  def down
    add_column :resource_pools, :vapp, :boolean
    ResourcePool.where(:type => VMWARE_INFRA_VAPP_CLASS).update_all(:vapp => true)
  end
end
