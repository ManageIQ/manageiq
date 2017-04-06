module ManageIQ::Providers::Redhat::InfraManager::Vm::Operations::Power
  def validate_pause
    validate_unsupported("Pause Operation")
  end

  def raw_start
    start_with_cloud_init = custom_attributes.find_by(:name => "miq_provision_boot_with_cloud_init")
    ext_management_system.ovirt_services.vm_start(self, start_with_cloud_init)
    start_with_cloud_init.try(&:destroy)
  end

  def raw_stop
    ext_management_system.ovirt_services.vm_stop(self)
  end

  def raw_suspend
    ext_management_system.ovirt_services.vm_suspend(self)
  end
end
