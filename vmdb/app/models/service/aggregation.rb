module Service::Aggregation
  extend ActiveSupport::Concern

  included do
    virtual_column :aggregate_direct_vm_cpus,                 :type => :integer
    virtual_column :aggregate_direct_vm_memory,               :type => :integer
    virtual_column :aggregate_direct_vm_disk_count,           :type => :integer
    virtual_column :aggregate_direct_vm_disk_space_allocated, :type => :integer
    virtual_column :aggregate_direct_vm_disk_space_used,      :type => :integer
    virtual_column :aggregate_direct_vm_memory_on_disk,       :type => :integer

    virtual_column :aggregate_all_vm_cpus,                    :type => :integer
    virtual_column :aggregate_all_vm_memory,                  :type => :integer
    virtual_column :aggregate_all_vm_disk_count,              :type => :integer
    virtual_column :aggregate_all_vm_disk_space_allocated,    :type => :integer
    virtual_column :aggregate_all_vm_disk_space_used,         :type => :integer
    virtual_column :aggregate_all_vm_memory_on_disk,          :type => :integer
  end


  def aggregate_direct_vm_cpus
    direct_vms.inject(0) { |aggregate, vm| aggregate += vm.num_cpu.to_i }
  end

  def aggregate_direct_vm_memory
    direct_vms.inject(0) { |aggregate, vm| aggregate += vm.ram_size.to_i }
  end

  def aggregate_direct_vm_disk_count
    direct_vms.inject(0) { |aggregate, vm| aggregate += vm.num_disks.to_i }
  end

  def aggregate_direct_vm_disk_space_allocated
    direct_vms.inject(0) { |aggregate, vm| aggregate += vm.allocated_disk_storage.to_i }
  end

  def aggregate_direct_vm_disk_space_used
    direct_vms.inject(0) { |aggregate, vm| aggregate += vm.used_disk_storage.to_i }
  end

  def aggregate_direct_vm_memory_on_disk
    direct_vms.inject(0) { |aggregate, vm| aggregate += vm.ram_size_in_bytes_by_state.to_i }
  end


  def aggregate_all_vm_cpus
    all_vms.inject(0) { |aggregate, vm| aggregate += vm.num_cpu.to_i }
  end

  def aggregate_all_vm_memory
    all_vms.inject(0) { |aggregate, vm| aggregate += vm.ram_size.to_i }
  end

  def aggregate_all_vm_disk_count
    all_vms.inject(0) { |aggregate, vm| aggregate += vm.num_disks.to_i }
  end

  def aggregate_all_vm_disk_space_allocated
    all_vms.inject(0) { |aggregate, vm| aggregate += vm.allocated_disk_storage.to_i }
  end

  def aggregate_all_vm_disk_space_used
    all_vms.inject(0) { |aggregate, vm| aggregate += vm.used_disk_storage.to_i }
  end

  def aggregate_all_vm_memory_on_disk
    all_vms.inject(0) { |aggregate, vm| aggregate += vm.ram_size_in_bytes_by_state.to_i }
  end

end
