module ManageIQ::Providers::Redhat::InfraManager::Vm::Operations::Power
  def validate_pause
    validate_unsupported("Pause Operation")
  end

  def raw_start
    start_with_cloud_init = custom_attributes.find_by(:name => "miq_provision_boot_with_cloud_init")
    with_provider_object do |rhevm_vm|
      rhevm_vm.start { |action| action.use_cloud_init(true) if start_with_cloud_init }
    end
    start_with_cloud_init.try(&:destroy)
  rescue Ovirt::VmAlreadyRunning
  end

  def raw_stop
    with_provider_object(&:stop)
  rescue Ovirt::VmIsNotRunning
  end

  def raw_suspend
    with_provider_object(&:suspend)
  end
end
