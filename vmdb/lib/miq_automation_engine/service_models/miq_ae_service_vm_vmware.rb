module MiqAeMethodService
  class MiqAeServiceVmVmware < MiqAeServiceVmInfra
    def set_number_of_cpus(count, options = {})
      sync_or_async_ems_operation(options[:sync], "set_number_of_cpus", [count])
    end

    def set_memory(size_mb, options = {})
      sync_or_async_ems_operation(options[:sync], "set_memory", [size_mb])
    end

    def add_disk(disk_name, disk_size_mb, options = {})
      sync_or_async_ems_operation(options[:sync], "add_disk", [disk_name, disk_size_mb])
    end

    private

    def sync_or_async_ems_operation(sync, method_name, args)
      ar_method do
        queue_options = {
          :class_name   => @object.class.name,
          :instance_id  => @object.id,
          :method_name  => method_name,
          :args         => args,
          :zone         => @object.my_zone,
          :role         => "ems_operations"
        }

        if sync
          task_options = { :name => method_name.titleize, :userid => "system" }
          task_id = MiqTask.generic_action_with_callback(task_options, queue_options)
          MiqTask.wait_for_taskid(task_id)
        else
          MiqQueue.put(queue_options)
        end
      end

      true
    end
  end
end
