module ManageIQ::Providers::Microsoft::InfraManager::Provision::Cloning
  MT_POINT_REGEX = %r{file://.*/([A-Z][:].*)}i

  def log_clone_options(clone_options)
    _log.info("Provisioning [#{source.name}] to [#{clone_options[:name]}]")
    _log.info("Source Image:                    [#{clone_options[:image_ref]}]")

    dumpObj(clone_options, "#{_log.prefix} Clone Options: ", $log, :info)
    dumpObj(options, "#{_log.prefix} Prov Options:  ", $log, :info, :protected => {:path => workflow_class.encrypted_options_field_regs})
  end

  def clone_complete?
    # TODO: monitor job state when asynchronous cloning is in place.
    true
  end

  def find_destination_in_vmdb(ems_ref)
    ManageIQ::Providers::Microsoft::InfraManager::Vm.find_by(:name => dest_name, :ems_ref => ems_ref)
  end

  def prepare_for_clone_task
    if dest_name.blank?
      raise MiqException::MiqProvisionError, "Provision Request's Destination VM Name=[#{dest_name}] cannot be blank"
    end

    if source.ext_management_system.vms.where(:name => dest_name).any?
      raise MiqException::MiqProvisionError, "A VM with name: [#{dest_name}] already exists"
    end

    {
      :name      => dest_name,
      :host      => dest_host,
      :datastore => dest_datastore,
    }
  end

  def dest_mount_point
    name = dest_datastore.name.scan(MT_POINT_REGEX).flatten.pop
    URI.decode(name.to_s).tr('/', '\\')
  end

  def dest_virtual_network
    get_option(:vlan)
  end

  def startup_ram
    get_option(:vm_memory)
  end

  def memory_limit
    get_option(:memory_limit)
  end

  def min_memory
    get_option(:memory_reserve)
  end

  def cpu_max
    get_option(:cpu_limit)
  end

  def cpu_reserve
    get_option(:cpu_reserve)
  end

  def cpu_count
    get_option(:number_of_cpus)
  end

  def dynamic_mem_min
    get_option(:vm_minimum_memory)
  end

  def dynamic_mem_max
    get_option(:vm_maximum_memory)
  end

  def memory_ps_script
    if get_option(:vm_dynamic_memory)
      "-DynamicMemoryEnabled $true \
       -MemoryMB #{startup_ram} \
       -DynamicMemoryMaximumMB #{dynamic_mem_max} \
       -DynamicMemoryMinimumMB #{dynamic_mem_min}"
    else
      "-DynamicMemoryEnabled $false \
       -MemoryMB #{startup_ram}"
    end
  end

  def cpu_ps_script
    cpu_script = "-CPUCount #{cpu_count} "
    cpu_script << "-CPUReserve #{cpu_reserve} " unless cpu_reserve.nil?
    cpu_script << "-CPUMaximumPercent #{cpu_max} " unless cpu_max.nil?

    cpu_script
  end

  def template_ps_script
    "(Get-SCVMTemplate -Name '#{source.name}')"
  end

  def logical_network_ps_script
    "(Get-SCLogicalNetwork -Name '#{dest_virtual_network}')"
  end

  def network_adapter_ps_script
    if dest_virtual_network.nil?
      $scvmm_log.info("Virtual Network is not available, network adapter will not be set")
      return
    end

    "$adapter = $vm | SCVirtualNetworkAdapter; \
     Set-SCVirtualNetworkAdapter \
      -VirtualNetworkAdapter $adapter \
      -LogicalNetwork #{logical_network_ps_script} | Out-Null;"
  end

  def build_ps_script
    <<-PS_SCRIPT
      Import-Module VirtualMachineManager | Out-Null; \
      Get-SCVMMServer localhost | Out-Null;\

      $vm = New-SCVirtualMachine \
        -Name '#{dest_name}' \
        -VMHost #{dest_host} \
        -Path '#{dest_mount_point}' \
        -VMTemplate #{template_ps_script}; \
      Set-SCVirtualMachine -VM $vm \
        #{cpu_ps_script} \
        #{memory_ps_script} | Out-Null;  \
      #{network_adapter_ps_script} \
      $vm | Select-Object ID | ConvertTo-Json
    PS_SCRIPT
  end

  def start_clone(_clone_options)
    $scvmm_log.debug(build_ps_script)
    json_results = source.ext_management_system.run_powershell_script(build_ps_script)
    vm_json      = ManageIQ::Providers::Microsoft::InfraManager.parse_json_results(json_results)
    phase_context[:new_vm_ems_ref] = vm_json["ID"]
  end
end
