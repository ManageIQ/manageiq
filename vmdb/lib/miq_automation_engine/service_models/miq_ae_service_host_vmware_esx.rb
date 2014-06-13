module MiqAeMethodService
  class MiqAeServiceHostVmwareEsx < MiqAeServiceHostVmware
    def shutdown(force = false)
      ar_method do
        MiqQueue.put(
          :class_name   => @object.class.name,
          :instance_id  => @object.id,
          :method_name  => "vim_shutdown",
          :zone         => @object.my_zone,
          :role         => "ems_operations",
          :args         => [force]
        ) if @object.is_vmware?
        true
      end
    end

    def reboot(force = false)
      ar_method do
        MiqQueue.put(
          :class_name   => @object.class.name,
          :instance_id  => @object.id,
          :method_name  => "vim_reboot",
          :zone         => @object.my_zone,
          :role         => "ems_operations",
          :args         => [force]
        ) if @object.is_vmware?
        true
      end
    end

    def enter_maintenance_mode(timeout = 0, evacuate = false)
      ar_method do
        MiqQueue.put(
          :class_name   => @object.class.name,
          :instance_id  => @object.id,
          :method_name  => "vim_enter_maintenance_mode",
          :zone         => @object.my_zone,
          :role         => "ems_operations",
          :args         => [timeout, evacuate]
        ) if @object.is_vmware?
        true
      end
    end

    def exit_maintenance_mode(timeout = 0)
      ar_method do
        MiqQueue.put(
          :class_name   => @object.class.name,
          :instance_id  => @object.id,
          :method_name  => "vim_exit_maintenance_mode",
          :zone         => @object.my_zone,
          :role         => "ems_operations",
          :args         => [timeout]
        ) if @object.is_vmware?
        true
      end
    end

    def in_maintenance_mode?
      object_send(:vim_in_maintenance_mode?) if @object.is_vmware?
    end

    def power_down_to_standby(timeout = 0, evacuate = false)
      ar_method do
        MiqQueue.put(
          :class_name   => @object.class.name,
          :instance_id  => @object.id,
          :method_name  => "vim_power_down_to_standby",
          :zone         => @object.my_zone,
          :role         => "ems_operations",
          :args         => [timeout, evacuate]
        ) if @object.is_vmware?
        true
      end
    end

    def power_up_from_standby(timeout = 0)
      ar_method do
        MiqQueue.put(
          :class_name   => @object.class.name,
          :instance_id  => @object.id,
          :method_name  => "vim_power_up_from_standby",
          :zone         => @object.my_zone,
          :role         => "ems_operations",
          :args         => [timeout]
        ) if @object.is_vmware?
        true
      end
    end

    def enable_vmotion(device = nil)
      ar_method do
        MiqQueue.put(
          :class_name   => @object.class.name,
          :instance_id  => @object.id,
          :method_name  => "vim_enable_vmotion",
          :zone         => @object.my_zone,
          :role         => "ems_operations",
          :args         => [device]
        ) if @object.is_vmware?
        true
      end
    end

    def disable_vmotion(device = nil)
      ar_method do
        MiqQueue.put(
          :class_name   => @object.class.name,
          :instance_id  => @object.id,
          :method_name  => "vim_disable_vmotion",
          :zone         => @object.my_zone,
          :role         => "ems_operations",
          :args         => [device]
        ) if @object.is_vmware?
        true
      end
    end

    def vmotion_enabled?(device = nil)
      object_send(:vim_vmotion_enabled?, device) if @object.is_vmware?
    end
  end
end
