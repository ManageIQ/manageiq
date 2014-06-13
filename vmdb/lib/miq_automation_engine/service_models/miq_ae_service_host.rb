module MiqAeMethodService
  class MiqAeServiceHost < MiqAeServiceModelBase
    expose :storages,              :association => true
    expose :vms,                   :association => true
    expose :ext_management_system, :association => true
    expose :hardware,              :association => true
    expose :switches,              :association => true
    expose :lans,                  :association => true
    expose :operating_system,      :association => true
    expose :guest_applications,    :association => true
    expose :ems_cluster,           :association => true
    expose :ems_events,            :association => true
    expose :ems_folder,            :association => true,      :method => :owning_folder
    expose :datacenter,            :association => true,      :method => :owning_datacenter
    expose :authentication_userid
    expose :authentication_password
    expose :event_log_threshold?
    expose :to_s
    expose :domain
    expose :files
    expose :directories

    METHODS_WITH_NO_ARGS = %w{scan}
    METHODS_WITH_NO_ARGS.each do |m|
      define_method(m) do
        ar_method do
          MiqQueue.put(
            :class_name   => @object.class.name,
            :instance_id  => @object.id,
            :method_name  => m,
            :zone         => @object.my_zone,
            :role         => "ems_operations"
          )
          true
        end
      end
    end

    def credentials(type = :remote)
       object_send(:auth_user_pwd, type)
    end

    def ems_custom_keys
      ar_method do
        @object.ems_custom_attributes.collect { |c| c.name }
      end
    end

    def ems_custom_get(key)
      ar_method do
        c1 = @object.ems_custom_attributes.find(:first, :conditions => {:name => key.to_s})
        c1 ? c1.value : nil
      end
    end

    def ems_custom_set(attribute, value)
      MiqQueue.put(
        :class_name   => @object.class.name,
        :instance_id  => @object.id,
        :method_name  => 'set_custom_field',
        :zone         => @object.my_zone,
        :role         => 'ems_operations',
        :args         => [attribute, value]
      ) if @object.is_vmware?
      true
    end

    def custom_keys
      object_send(:miq_custom_keys)
    end

    def custom_get(key)
      object_send(:miq_custom_get, key)
    end

    def custom_set(key, value)
      ar_method do
        @object.miq_custom_set(key, value)
        @object.save
      end
      value
    end

    def ssh_exec(script)
      object_send(:ssh_run_script, script)
    end

    def get_realtime_metric(metric, range, function)
      object_send(:get_performance_metric, :realtime, metric, range, function)
    end

    def current_memory_usage
      object_send(:current_memory_usage)
    end

    def current_cpu_usage
      object_send(:current_cpu_usage)
    end

    def current_memory_headroom
      object_send(:current_memory_headroom)
    end
  end
end
