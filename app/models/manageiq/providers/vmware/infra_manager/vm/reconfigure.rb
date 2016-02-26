module ManageIQ::Providers::Vmware::InfraManager::Vm::Reconfigure
  # Show Reconfigure VM task
  def reconfigurable?
    true
  end

  def max_total_vcpus
    [host.hardware.cpu_total_cores, max_total_vcpus_by_version].min
  end

  def max_total_vcpus_by_version
    case hardware.virtual_hw_version
    when "04"       then 4
    when "07"       then 8
    when "08"       then 32
    when "09", "10" then 64
    end
  end

  def max_cpu_cores_per_socket(_total_vcpus = nil)
    case hardware.virtual_hw_version
    when "04"       then 1
    when "07"       then [1, 2, 4, 8].include?(max_total_vcpus) ? max_total_vcpus : 1
    else            max_total_vcpus
    end
  end

  def max_vcpus
    max_total_vcpus
  end

  def max_memory_mb
    case hardware.virtual_hw_version
    when "04"             then   64.gigabyte / 1.megabyte
    when "07"             then  255.gigabyte / 1.megabyte
    when "08", "09", "10" then 1011.gigabyte / 1.megabyte
    end
  end

  def build_config_spec(task_options)
    VimHash.new("VirtualMachineConfigSpec") do |vmcs|
      case hardware.virtual_hw_version
      when "07"
        ec =  VimArray.new('ArrayOfOptionValue')
        ec << VimHash.new('OptionValue') do |ov|
          ov.key   = "cpuid.coresPerSocket"
          ov.value = VimString.new(task_options[:cores_per_socket].to_s, nil, "xsd:string")
        end
        vmcs.extraConfig = ec
      else
        set_spec_option(vmcs, :numCoresPerSocket, task_options[:cores_per_socket], :to_i)
      end
      set_spec_option(vmcs, :memoryMB, task_options[:vm_memory],      :to_i)
      set_spec_option(vmcs, :numCPUs,  task_options[:number_of_cpus], :to_i)
    end
  end

  # Set the value if it is not nil
  def set_spec_option(obj, property, value, modifier = nil)
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
end
