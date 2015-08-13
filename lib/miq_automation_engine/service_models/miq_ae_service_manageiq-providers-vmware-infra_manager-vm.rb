module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Vm < MiqAeServiceManageIQ_Providers_InfraManager_Vm

    def set_number_of_cpus(count, options = {})
      sync_or_async_ems_operation(options[:sync], "set_number_of_cpus", [count])
    end

    def set_memory(size_mb, options = {})
      sync_or_async_ems_operation(options[:sync], "set_memory", [size_mb])
    end

    def add_disk(disk_name, disk_size_mb, options = {})
      sync_or_async_ems_operation(options[:sync], "add_disk", [disk_name, disk_size_mb])
    end

    def create_snapshot(name, desc = nil, memory = false)
      snapshot_operation(:create_snapshot, :name => name, :description => desc, :memory => !!memory)
    end

    def remove_all_snapshots
      snapshot_operation(:remove_all_snapshots)
    end

    def remove_snapshot(snapshot_id)
      snapshot_operation(:remove_snapshot, :snap_selected => snapshot_id)
    end

    def revert_to_snapshot(snapshot_id)
      snapshot_operation(:revert_to_snapshot, :snap_selected => snapshot_id)
    end

    def snapshot_operation(task, options = {})
      options.merge!(:ids => [id], :task => task.to_s)
      Vm.process_tasks(options)
    end
  end
end
