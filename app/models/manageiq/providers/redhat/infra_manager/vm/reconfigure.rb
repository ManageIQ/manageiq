module ManageIQ::Providers::Redhat::InfraManager::Vm::Reconfigure
  # Show Reconfigure VM task
  def reconfigurable?
    true
  end

  def max_total_vcpus
    # the default value of MaxNumOfVmCpusTotal for RHEV 3.1 - 3.4
    160
  end

  def max_cpu_cores_per_socket
    # the default value of MaxNumOfCpuPerSocket for RHEV 3.1 - 3.4
    16
  end

  def max_vcpus
    # the default value of MaxNumofVmSockets for RHEV 3.1 - 3.4
    16
  end

  def max_memory_mb
    2.terabyte / 1.megabyte
  end

  def build_config_spec(task_options)
    {"numCoresPerSocket" => task_options[:cores_per_socket].to_i,
      "memoryMB"         => task_options[:vm_memory].to_i,
      "numCPUs"          => task_options[:number_of_cpus].to_i
    }
  end
end
