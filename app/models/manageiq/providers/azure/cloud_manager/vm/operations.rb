module ManageIQ::Providers::Azure::CloudManager::Vm::Operations
  include_concern 'Power'

  def raw_destroy
    raise "VM has no #{ui_lookup(:table => "ext_management_systems")}, unable to destroy VM" unless ext_management_system
    provider_service.delete(name, resource_group)
    update_attributes!(:raw_power_state => "Deleting")
  end
end
