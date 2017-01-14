module MiqAeMethodService
  class MiqAeServiceVmOrTemplate < MiqAeServiceModelBase
    require_relative "mixins/miq_ae_service_ems_operations_mixin"
    include MiqAeServiceEmsOperationsMixin
    require_relative "mixins/miq_ae_service_retirement_mixin"
    include MiqAeServiceRetirementMixin
    require_relative "mixins/miq_ae_service_inflector_mixin"
    include MiqAeServiceInflectorMixin
    require_relative "mixins/miq_ae_service_custom_attribute_mixin"
    include MiqAeServiceCustomAttributeMixin

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
    expose :registered?
    expose :to_s
    expose :event_threshold?
    expose :event_log_threshold?
    expose :performances_maintains_value_for_duration?
    expose :reconfigured_hardware_value?
    expose :changed_vm_value?
    expose :files,                 :association => true
    expose :directories,           :association => true
    expose :refresh, :method => :refresh_ems
    expose :tenant,                :association => true
    expose :accounts,              :association => true
    expose :users,                 :association => true
    expose :groups,                :association => true
    expose :compliances,           :association => true
    expose :last_compliance,       :association => true
    expose :ems_events,            :association => true


    METHODS_WITH_NO_ARGS = %w(start stop suspend unregister collect_running_processes shutdown_guest standby_guest reboot_guest)
    METHODS_WITH_NO_ARGS.each do |m|
      define_method(m) do
        ar_method do
          MiqQueue.put(
            :class_name  => @object.class.name,
            :instance_id => @object.id,
            :method_name => m,
            :zone        => @object.my_zone,
            :role        => "ems_operations"
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
        :class_name  => @object.class.name,
        :instance_id => @object.id,
        :method_name => 'migrate_via_ids',
        :zone        => @object.my_zone,
        :role        => 'ems_operations',
        :args        => args
      )
      true
    end

    def owner
      evm_owner = object_send(:evm_owner)
      wrap_results(evm_owner)
    end
    association :owner

    # Used to return string object instead of VimString to automate methods which end up with a DrbUnknow object.
    def ems_ref_string
      object_send(:ems_ref)
    end

    def remove_from_vmdb
      _log.info "Removing #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}>"
      object_send(:destroy)
      @object = nil
      true
    end

    def scan(scan_categories = nil)
      options = scan_categories.nil? ? {} : {:categories => scan_categories}
      job = object_send(:scan, "system", options)
      wrap_results(job)
    end

    def unlink_storage
      _log.info "Unlinking storage on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}>"
      object_send(:update_attributes, :storage_id => nil)
      true
    end

    def ems_custom_keys
      ar_method do
        @object.ems_custom_attributes.collect(&:name)
      end
    end

    def ems_custom_get(key)
      ar_method do
        c1 = @object.ems_custom_attributes.find_by(:name => key.to_s)
        c1.try(:value)
      end
    end

    def ems_custom_set(attribute, value)
      _log.info "Setting EMS Custom Key on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> with key=#{attribute.inspect} to #{value.inspect}"
      MiqQueue.put(
        :class_name  => @object.class.name,
        :instance_id => @object.id,
        :method_name => 'set_custom_field',
        :zone        => @object.my_zone,
        :role        => 'ems_operations',
        :args        => [attribute, value]
      )
      true
    end

    def owner=(owner)
      raise ArgumentError, "owner must be nil or a MiqAeServiceUser" unless owner.nil? || owner.kind_of?(MiqAeMethodService::MiqAeServiceUser)

      ar_method do
        @object.evm_owner = owner && owner.instance_variable_get("@object")
        _log.info "Setting EVM Owning User on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> to #{@object.evm_owner.inspect}"
        @object.save
      end
    end

    def group=(group)
      raise ArgumentError, "group must be nil or a MiqAeServiceMiqGroup" unless group.nil? || group.kind_of?(MiqAeMethodService::MiqAeServiceMiqGroup)

      ar_method do
        @object.miq_group = group && group.instance_variable_get("@object")
        _log.info "Setting EVM Owning Group on #{@object.class.name} id:<#{@object.id}>, name:<#{@object.name}> to #{@object.miq_group.inspect}"
        @object.save
      end
    end

    def remove_from_disk(sync = true)
      sync_or_async_ems_operation(sync, "vm_destroy", [])
    end
  end
end
