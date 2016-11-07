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
    {
      "numCoresPerSocket" => (task_options[:cores_per_socket].to_i if task_options[:cores_per_socket]),
      "memoryMB"          => (task_options[:vm_memory].to_i if task_options[:vm_memory]),
      "numCPUs"           => (task_options[:number_of_cpus].to_i if task_options[:number_of_cpus]),
      "disksRemove"       => task_options[:disk_remove],
      "disksAdd"          => (spec_for_added_disks(task_options[:disk_add]) if task_options[:disk_add])
    }
  end

  def spec_for_added_disks(disks)
    disks.each { |disk_spec| disk_spec["format"] = disk_format_for(disk_spec["thin_provisioned"]) }
    {
      "disks"           => disks,
      "ems_storage_uid" => ManageIQ::Providers::Redhat::InfraManager.extract_ems_ref_id(storage.ems_ref),
    }
  end

  FILE_STORAGE_TYPE = %w(NFS GLUSTERFS VMFS).freeze
  BLOCK_STORAGE_TYPE = %w(FCP ISCSI).freeze

  def disk_format_for(thin_provisioned)
    if FILE_STORAGE_TYPE.include?(storage.store_type)
      "raw"
    elsif BLOCK_STORAGE_TYPE.include?(storage.store_type)
      thin_provisioned ? "cow" : "raw"
    else
      "raw"
    end
  end
end
