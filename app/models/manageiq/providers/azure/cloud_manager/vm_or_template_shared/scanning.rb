module ManageIQ::Providers::Azure::CloudManager::VmOrTemplateShared::Scanning
  def perform_metadata_scan(ost)
    require 'MiqVm/miq_azure_vm'

    vm_args = { :name => name }
    _log.debug "name: #{name} (template = #{template})"
    if template
      _log.debug "image_uri: #{uid_ems}"
      vm_args[:image_uri] = uid_ems
    else
      _log.debug "resource_group: #{resource_group}"
      vm_args[:resource_group] = resource_group
    end

    ost.scanTime = Time.now.utc unless ost.scanTime
    armrest      = ext_management_system.connect 

    begin
      miq_vm = MiqAzureVm.new(armrest, vm_args)
      scan_via_miq_vm(miq_vm, ost)
    ensure
      miq_vm.unmount if miq_vm
    end
  end

  def perform_metadata_sync(ost)
    sync_stashed_metadata(ost)
  end

  def proxies4job(_job)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this Instance'
    }
  end

  def has_active_proxy?
    true
  end

  def has_proxy?
    true
  end

  def requires_storage_for_scan?
    false
  end

  def validate_smartstate_analysis
    validate_supported_check("Smartstate Analysis")
  end
end
