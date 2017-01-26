module CloudVolume::Operations
  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
  end

  module InstanceMethods
    def attach_volume_queue(userid, server_ems_ref, device = nil)
      task_opts = {
        :action => "attaching Cloud Volume for user #{userid}",
        :userid => userid
      }
      queue_opts = {
        :class_name  => self.class.name,
        :method_name => 'attach_volume',
        :instance_id => id,
        :role        => 'ems_operations',
        :zone        => ext_management_system.my_zone,
        :args        => [server_ems_ref, device]
      }
      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end

    def attach_volume(server_ems_ref, device = nil)
      raw_attach_volume(server_ems_ref, device)
    end

    def validate_attach_volume
      validate_unsupported(_("Attach Volume Operation"))
    end

    def detach_volume_queue(userid, server_ems_ref)
      task_opts = {
        :action => "detaching Cloud Volume for user #{userid}",
        :userid => userid
      }
      queue_opts = {
        :class_name  => self.class.name,
        :method_name => 'detach_volume',
        :instance_id => id,
        :role        => 'ems_operations',
        :zone        => ext_management_system.my_zone,
        :args        => [server_ems_ref]
      }
      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end

    def detach_volume(server_ems_ref)
      raw_detach_volume(server_ems_ref)
    end

    def validate_detach_volume
      validate_unsupported(_("Detach Volume Operation"))
    end

    private

    def validate_unsupported(message_prefix)
      self.class.validate_unsupported(message_prefix)
    end

    def validation_failed(operation, reason)
      self.class.validation_failed(operation, reason)
    end

    def validate_volume
      self.class.validate_volume(ext_management_system)
    end

    def validate_volume_available
      msg = validate_volume
      return {:available => msg[:available], :message => msg[:message]} unless msg.nil?
      return {:available => true, :message => nil} if status == "available"
      {:available => false, :message => _("The volume can't be attached, status has to be 'available'")}
    end

    def validate_volume_in_use
      msg = validate_volume
      return {:available => msg[:available], :message => msg[:message]} unless msg[:available]
      return {:available => true, :message => nil} if status == "in-use"
      {:available => false, :message => _("The volume can't be detached, status has to be 'in-use'")}
    end
  end

  module ClassMethods
    def validate_volume(ext_management_system)
      if ext_management_system.nil?
        return {:available => false,
                :message   => _("The Volume is not connected to an active %{table}") %
                  {:table => ui_lookup(:table => "ext_management_systems")}}
      end
      {:available => true, :message => nil}
    end

    def validate_unsupported(message_prefix)
      {:available => false, :message => _("%{message} is not available for %{name}.") % {:message => message_prefix,
                                                                                         :name    => name}}
    end

    def validation_failed(operation, reason)
      {:available => false,
       :message   => _("Validation failed for %{name} operation %{operation}. %{reason}") % {:name      => name,
                                                                                             :operation => operation,
                                                                                             :reason    => reason}}
    end
  end
end
