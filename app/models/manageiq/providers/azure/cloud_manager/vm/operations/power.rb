module ManageIQ::Providers::Azure::CloudManager::Vm::Operations::Power
  extend ActiveSupport::Concern
  include SupportsFeatureMixin

  included do
    supports_not :pause, :reason => _("Pause operation is not available for VM or Template.")
  end

  def raw_suspend
    provider_service.stop(name, resource_group)
    update_attributes!(:raw_power_state => "VM stopping")
  end

  def raw_start
    provider_service.start(name, resource_group)
    update_attributes!(:raw_power_state => "VM starting")
  end

  def raw_stop
    provider_service.deallocate(name, resource_group)
    update_attributes!(:raw_power_state => "VM deallocating")
  end

  def raw_restart
    provider_service.restart(name, resource_group)
    update_attributes!(:raw_power_state => "VM starting")
  end
end
