module ManageIQ::Providers::Vmware::InfraManager::Provision::Configuration::Container
  def build_config_spec
    VimHash.new("VirtualMachineConfigSpec") do |vmcs|
      vmcs.annotation = build_vm_notes

      #####################################################################################################
      # Note: VMware currently seems to ignore the CPU/memory limit/reservation settings during a clone
      #       Modifying the hardware in the VC UI is marked as "experimental".)
      # So, we have to configure these values after the clone process.
      #####################################################################################################
      set_spec_option(vmcs, :memoryMB, :vm_memory, nil, :to_i)

      sockets = get_option(:number_of_sockets).to_i  # New-style based on VMware KB: 1010184
      cores   = get_option(:cores_per_socket).to_i   # New-style

      if sockets.zero?
        set_spec_option(vmcs, :numCPUs, :number_of_cpus, nil, :to_i)
      else
        # Setting coresPerSocket is only supported on VMware hardware version 7 and above.
        vm_hardware_version = source.hardware.virtual_hw_version rescue nil
        if vm_hardware_version.to_i < 7
          _log.warn "VMware hardware version <#{vm_hardware_version}> does not support setting coresPerSocket" if cores >= 1
          cores = nil
        end

        # For VMware you need to set the total number of CPUs and the cores per socket.
        numCpus = if cores.nil?
                    sockets
                  else
                    cores = cores.to_i
                    cores = 1 if cores < 1
                    sockets * cores
                  end
        set_spec_option(vmcs, :numCPUs, nil, nil, :to_i, numCpus)

        if cores.to_i >= 1
          vmcs_ec = vmcs.extraConfig = VimArray.new('ArrayOfOptionValue')
          vmcs_ec << VimHash.new('OptionValue') do |ov|
            ov.key   = "cpuid.coresPerSocket"
            ov.value = VimString.new(cores.to_s, nil, "xsd:string")
          end
        end
      end

      build_config_network_adapters(vmcs)
      build_config_disk_spec(vmcs)
    end
  end

  def build_vm_notes
    new_vm_guid = phase_context[:new_vm_validation_guid]
    vm_notes = get_option(:vm_notes).to_s.strip
    vm_notes += "\n\n" unless vm_notes.blank?
    vm_notes += "MIQ GUID=#{new_vm_guid}"
    service, _service_resource = get_service_and_service_resource
    if service
      vm_notes += "\n\nParent Service: #{service.name} (#{service.guid})"
    end
    _log.info "Setting VM annotations to [#{vm_notes}]"
    vm_notes
  end

  def set_spec_option(obj, property, key, default_value = nil, modifier = nil, override_value = nil)
    if key.nil?
      value = get_option(nil, override_value)
    else
      value = override_value.nil? ? get_option(key) : override_value
    end
    value = default_value if value.nil?
    unless value.nil?
      # Modifier is a method like :to_s or :to_i
      value = value.to_s if [true, false].include?(value)
      value = value.send(modifier) unless modifier.nil?
      _log.info "#{property} was set to #{value} (#{value.class})"
      obj.send("#{property}=", value)
    else
      value = obj.send("#{property}")
      if value.nil?
        _log.info "#{property} was NOT set due to nil"
      else
        _log.info "#{property} inheriting value from spec: #{value} (#{value.class})"
      end
    end
  end

  def add_device_config_spec(vmcs, operation)
    vmcs_vca = vmcs.deviceChange ||= VimArray.new('ArrayOfVirtualDeviceConfigSpec')
    vmcs_vca << VimHash.new('VirtualDeviceConfigSpec') do |vdcs|
      vdcs.operation = operation
      yield(vdcs)
    end
  end

  def get_config_spec_value(data_hash, default_value, vim_type, lookup_path)
    value = data_hash.fetch_path(lookup_path)
    value = default_value if value.to_s.strip.blank?
    return value if vim_type.nil?
    VimString.new(value, vim_type)
  end

  def get_next_device_idx
    @new_device_idx ||= -100
    @new_device_idx -= 1
  end

  def set_cpu_and_memory_allocation(vm)
    config_spec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
      vmcs.cpuAllocation    = VimHash.new("ResourceAllocationInfo") do |rai|
        set_spec_option(rai, :limit,       :cpu_limit,   nil, :to_i)
        set_spec_option(rai, :reservation, :cpu_reserve, nil, :to_i)
      end

      vmcs.memoryAllocation = VimHash.new("ResourceAllocationInfo") do |rai|
        set_spec_option(rai, :limit,       :memory_limit,   nil, :to_i)
        set_spec_option(rai, :reservation, :memory_reserve, nil, :to_i)
      end
    end

    _log.info("Calling VM reconfiguration")
    dumpObj(config_spec, "#{_log.prefix} Post-create Config spec: ", $log, :info)
    vm.spec_reconfigure(config_spec)
  end
end
