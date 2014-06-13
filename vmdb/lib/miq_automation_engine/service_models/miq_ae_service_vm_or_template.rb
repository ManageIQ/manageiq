module MiqAeMethodService
  class MiqAeServiceVmOrTemplate < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :storage,               :association => true
    expose :host,                  :association => true
    expose :hardware,              :association => true
    expose :operating_system,      :association => true
    expose :guest_applications,    :association => true
    expose :miq_provision,         :association => true
    expose :ems_cluster,           :association => true
    expose :snapshots,             :association => true
    expose :direct_service,        :association => true
    expose :service,               :association => true
    expose :ems_folder,            :association => true, :method => :parent_folder
    expose :ems_blue_folder,       :association => true, :method => :parent_blue_folder
    expose :resource_pool,         :association => true, :method => :parent_resource_pool
    expose :datacenter,            :association => true, :method => :parent_datacenter
    expose :remove_from_disk,                            :method => :vm_destroy, :override_return => true
    expose :registered?
    expose :to_s
    expose :event_threshold?
    expose :event_log_threshold?
    expose :performances_maintains_value_for_duration?
    expose :reconfigured_hardware_value?
    expose :changed_vm_value?
    expose :retire_now
    expose :files
    expose :directories
    expose :refresh, :method => :refresh_ems

    METHODS_WITH_NO_ARGS = %w{start stop suspend unregister collect_running_processes shutdown_guest standby_guest reboot_guest}
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

    def migrate(host, pool = nil, priority = "defaultPriority", state = nil)
      raise "Host Class must be MiqAeServiceHost, but is <#{host.class.name}>" unless host.kind_of?(MiqAeServiceHost)
      raise "Pool Class must be MiqAeServiceResourcePool, but is <#{pool.class.name}>" unless pool.nil? || pool.kind_of?(MiqAeServiceResourcePool)

      args = []
      args << host['id']
      args << (pool.nil? ? nil : pool['id'])
      args << priority
      args << state

      MiqQueue.put(
        :class_name   => @object.class.name,
        :instance_id  => @object.id,
        :method_name  => 'migrate_via_ids',
        :zone         => @object.my_zone,
        :role         => 'ems_operations',
        :args         => args
      )
      true
    end

    def owner
      evm_owner = object_send(:evm_owner)
      return wrap_results(evm_owner)
    end
    association :owner

    # Used to return string object instead of VimString to automate methods which end up with a DrbUnknow object.
    def ems_ref_string
      object_send(:ems_ref)
    end

    def remove_from_vmdb
      $log.info "MIQ(#{self.class.name}#remove_from_vmdb) Removing #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}>"
      object_send(:destroy)
      @object = nil
      true
    end

    def scan(scan_categories = nil)
      options = scan_categories.nil?  ? {} : {:categories => scan_categories}
      job = object_send(:scan, "system", options)
      return wrap_results(job)
    end

    def unlink_storage
      $log.info "MIQ(#{self.class.name}#unlink_storage) Unlinking storage on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}>"
      object_send(:update_attributes, :storage_id => nil)
      true
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
      $log.info "MIQ(#{self.class.name}#ems_custom_set) Setting EMS Custom Key on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> with key=#{attribute.inspect} to #{value.inspect}"
      MiqQueue.put(
        :class_name   => @object.class.name,
        :instance_id  => @object.id,
        :method_name  => 'set_custom_field',
        :zone         => @object.my_zone,
        :role         => 'ems_operations',
        :args         => [attribute, value]
      )
      true
    end

    def custom_keys
      object_send(:miq_custom_keys)
    end

    def custom_get(key)
      object_send(:miq_custom_get, key)
    end

    def custom_set(key, value)
      $log.info "MIQ(#{self.class.name}#custom_set) Setting EVM Custom Key on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> with key=#{key.inspect} to #{value.inspect}"
      ar_method do
        @object.miq_custom_set(key, value)
        @object.save
      end
      value
    end

    def retires_on=(date)
      $log.info "MIQ(#{self.class.name}#retires_on=) Setting Retirement Date on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> to #{date.inspect}"
      ar_method do
        @object.retires_on = date
        @object.save
      end
    end

    def retirement_warn=(seconds)
      $log.info "MIQ(#{self.class.name}#retirement_warn=) Setting Retirement Warning on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> to #{seconds.inspect}"
      ar_method do
        @object.retirement_warn = seconds
        @object.save
      end
    end

    def owner=(owner)
      raise ArgumentError, "owner must be nil or a MiqAeServiceUser" unless (owner.nil? || owner.kind_of?(MiqAeMethodService::MiqAeServiceUser))

      ar_method do
        @object.evm_owner = owner && owner.instance_variable_get("@object")
        $log.info "MIQ(#{self.class.name}#owner=) Setting EVM Owning User on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> to #{@object.evm_owner.inspect}"
        @object.save
      end
    end

    def group=(group)
      raise ArgumentError, "group must be nil or a MiqAeServiceMiqGroup" unless (group.nil? || group.kind_of?(MiqAeMethodService::MiqAeServiceMiqGroup))

      ar_method do
        @object.miq_group = group && group.instance_variable_get("@object")
        $log.info "MIQ(#{self.class.name}#group=) Setting EVM Owning Group on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> to #{@object.miq_group.inspect}"
        @object.save
      end
    end

    def create_snapshot(name, desc = nil)
      snapshot_operation(:create_snapshot, {:name=>name, :description => desc})
    end

    def remove_all_snapshots
      snapshot_operation(:remove_all_snapshots)
    end

    def remove_snapshot(snapshot_id)
      snapshot_operation(:remove_snapshot, {:snap_selected => snapshot_id})
    end

    def revert_to_snapshot(snapshot_id)
      snapshot_operation(:revert_to_snapshot, {:snap_selected => snapshot_id})
    end

    def snapshot_operation(task, options = {})
      options.merge!(:ids=>[self.id], :task=>task.to_s)
      Vm.process_tasks(options)
    end
  end
end
