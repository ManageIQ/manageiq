class EmsEvent < EventStream
  include_concern 'Automate'

  virtual_column :group,       :type => :symbol
  virtual_column :group_level, :type => :symbol
  virtual_column :group_name,  :type => :string

  CLONE_TASK_COMPLETE = "CloneVM_Task_Complete"
  SOURCE_DEST_TASKS = [
    'CloneVM_Task',
    'MarkAsTemplate',
    'MigrateVM_Task',
    'RelocateVM_Task',
    'Rename_Task',
  ]

  def handle_event
    EmsEventHelper.new(self).handle
  rescue => err
    _log.log_backtrace(err)
  end

  def self.task_final_events
    VMDB::Config.new('event_handling').config[:task_final_events]
  end

  def self.event_groups
    VMDB::Config.new('event_handling').config[:event_groups]
  end

  def self.bottleneck_event_groups
    VMDB::Config.new('event_handling').config[:bottleneck_event_groups]
  end

  def self.group_and_level(event_type)
    group, v = event_groups.find { |_k, v| v[:critical].include?(event_type) || v[:detail].include?(event_type) }
    if group.nil?
      group, level = :other, :detail
    else
      level = v[:detail].include?(event_type) ? :detail : :critical
    end
    return group, level
  end

  def self.group_name(group)
    return nil if group.nil?
    group = event_groups[group.to_sym]
    return nil if group.nil?
    group[:name]
  end

  def self.add_queue(meth, ems_id, event)
    MiqQueue.put(
      :target_id   => ems_id,
      :class_name  => "EmsEvent",
      :method_name => meth,
      :args        => [event],
      :queue_name  => "ems",
      :role        => "event"
    )
  end

  def self.add_vc(ems_id, event)
    add(ems_id, ManageIQ::Providers::Vmware::InfraManager::EventParser.event_to_hash(event, ems_id))
  end

  def self.add_rhevm(ems_id, event)
    add(ems_id, ManageIQ::Providers::Redhat::InfraManager::EventParser.event_to_hash(event, ems_id))
  end

  def self.add_openstack(ems_id, event)
    add(ems_id, ManageIQ::Providers::Openstack::CloudManager::EventParser.event_to_hash(event, ems_id))
  end

  def self.add_openstack_network(ems_id, event)
    add(ems_id, ManageIQ::Providers::Openstack::NetworkManager::EventParser.event_to_hash(event, ems_id))
  end

  def self.add_openstack_infra(ems_id, event)
    add(ems_id, ManageIQ::Providers::Openstack::InfraManager::EventParser.event_to_hash(event, ems_id))
  end

  def self.add_kubernetes(ems_id, event)
    add(ems_id, ManageIQ::Providers::Kubernetes::ContainerManager::EventParser.event_to_hash(event, ems_id))
  end

  def self.add_azure(ems_id, event)
    add(ems_id, ManageIQ::Providers::Azure::CloudManager::EventParser.event_to_hash(event, ems_id))
  end

  def self.add_google(ems_id, event)
    add(ems_id, ManageIQ::Providers::Google::CloudManager::EventParser.event_to_hash(event, ems_id))
  end

  def self.add(ems_id, event_hash)
    event_type = event_hash[:event_type]
    raise MiqException::Error, _("event_type must be set in event") if event_type.nil?

    event_hash[:ems_id] = ems_id
    process_vm_in_event!(event_hash)
    process_vm_in_event!(event_hash, :prefix => "dest_")
    process_host_in_event!(event_hash)
    process_host_in_event!(event_hash, :prefix => "dest_")
    process_availability_zone_in_event!(event_hash)
    process_cluster_in_event!(event_hash)
    process_container_entities_in_event!(event_hash)
    process_middleware_entities_in_event!(event_hash)

    # Write the event
    new_event = create_event(event_hash)
    # Create a 'completed task' event if this is the last in a series of events
    create_completed_event(event_hash) if task_final_events.key?(event_type.to_sym)
    new_event
  end

  def self.process_object_in_event!(klass, event, options = {})
    prefix      = options[:prefix]
    key_prefix  = options[:key_prefix] || klass.name.underscore
    id_key      = options[:id_key] || "#{prefix}#{key_prefix}_id".to_sym
    ems_ref_key = options[:ems_ref_key] || "#{prefix}#{key_prefix}_ems_ref".to_sym
    name_key    = options[:name_key] || "#{prefix}#{key_prefix}_name".to_sym

    if event[id_key].nil?
      ems_ref = event[ems_ref_key]
      object  = klass.base_class.find_by(:ems_ref => ems_ref, :ems_id => event[:ems_id]) unless ems_ref.nil?

      unless object.nil?
        event[id_key]     = object.id
        event[name_key] ||= object.name
      end
    end
  end

  def self.process_vm_in_event!(event, options = {})
    prefix           = options[:prefix]
    options[:id_key] = "#{prefix}vm_or_template_id".to_sym
    process_object_in_event!(Vm, event, options)

    if options[:id_key] == :vm_or_template_id && event[:vm_or_template_id].nil?
      # uid_ems is used for non-VC events, and should be nil for VC events.
      uid_ems = event.fetch_path(:full_data, :vm, :uid_ems)
      vm      = VmOrTemplate.find_by_uid_ems(uid_ems) unless uid_ems.nil?

      unless vm.nil?
        event[:vm_or_template_id] = vm.id
        event[:vm_name] ||= vm.name
      end
    end
  end

  def self.process_host_in_event!(event, options = {})
    process_object_in_event!(Host, event, options)
  end

  def self.process_container_entities_in_event!(event, _options = {})
    [ContainerNode, ContainerGroup, ContainerReplicator].each do |entity|
      process_object_in_event!(entity, event, :ems_ref_key => :ems_ref)
    end
    event.except!(:ems_ref)
  end

  def self.process_middleware_entities_in_event!(event, _options = {})
    middleware_type = event[:middleware_type]
    if middleware_type
      klass = middleware_type.safe_constantize
      unless klass.nil?
        process_object_in_event!(klass, event, :ems_ref_key => :middleware_ref)
      end
    end
    event.except!(:middleware_ref, :middleware_type)
  end

  def self.process_availability_zone_in_event!(event, options = {})
    process_object_in_event!(AvailabilityZone, event, options)
    if event[:availability_zone_id].nil? && event[:vm_or_template_id]
      vm = VmOrTemplate.find(event[:vm_or_template_id])
      if vm.respond_to? :availability_zone
        availability_zone = vm.availability_zone
        unless availability_zone.nil?
          event[:availability_zone_id]     = availability_zone.id
        end
      end
    end
    # there's no "availability_zone_name" column in ems_event
    # availability_zone_name may be added by process_vm_in_event
    # prevent EmsEvent from trying to set the event attribute for availability_zone_name
    event.delete(:availability_zone_name)
  end

  def self.process_cluster_in_event!(event, options = {})
    process_object_in_event!(EmsCluster, event, options)
  end

  def self.first_chained_event(ems_id, chain_id)
    return nil if chain_id.nil?
    EmsEvent.where(:ems_id => ems_id, :chain_id => chain_id).order(:id).first
  end

  def first_chained_event
    @first_chained_event ||= EmsEvent.first_chained_event(ems_id, chain_id) || self
  end

  def group
    return @group unless @group.nil?
    @group, @group_level = self.class.group_and_level(event_type)
    @group
  end

  def group_level
    return @group_level unless @group_level.nil?
    @group, @group_level = self.class.group_and_level(event_type)
    @group_level
  end

  def group_name
    @group_name ||= self.class.group_name(group)
  end

  def get_target(target_type)
    target_type = target_type.to_s
    if target_type =~ /^first_chained_(.+)$/
      target_type = $1
      event = first_chained_event
    else
      event = self
    end

    target_type = "src_vm_or_template"  if target_type == "src_vm"
    target_type = "dest_vm_or_template" if target_type == "dest_vm"
    return ExtManagementSystem.last if event.event_type == "hawkular_event"
    #target_type = "middleware_server"   if event.event_type == "hawkular_event"

    event.send(target_type)
  end

  def tenant_identity
    (vm_or_template || ext_management_system).tenant_identity
  end

  private

  def self.create_event(event)
    event.delete_if { |k,| k.to_s.ends_with?("_ems_ref") }

    new_event = EmsEvent.create(event) unless EmsEvent.exists?(
      :event_type => event[:event_type],
      :timestamp  => event[:timestamp],
      :chain_id   => event[:chain_id],
      :ems_id     => event[:ems_id]
    )
    new_event.handle_event if new_event
    new_event
  end

  def self.create_completed_event(event, orig_task = nil)
    if orig_task.nil?
      orig_task = first_chained_event(event[:ems_id], event[:chain_id])
      return if orig_task.nil?
    end

    if task_final_events[event[:event_type].to_sym].include?(orig_task.event_type)
      event = MiqHashStruct.new(event)

      # Determine which event has the details for the source and dest
      if SOURCE_DEST_TASKS.include?(orig_task.event_type)
        source_event = orig_task
        dest_event = event
      else
        source_event = event
        dest_event = nil
      end

      # Build the 'completed task' event
      new_event_type = "#{orig_task.event_type}_Complete"
      new_event = {
        :event_type        => new_event_type,
        :chain_id          => event.chain_id,
        :is_task           => true,
        :source            => 'EVM',
        :ems_id            => event.ems_id,

        :message           => "#{orig_task.event_type} Completed",
        :timestamp         => event.timestamp,

        :host_name         => source_event.host_name,
        :host_id           => source_event.host_id,
        :vm_name           => source_event.vm_name,
        :vm_location       => source_event.vm_location,
        :vm_or_template_id => source_event.vm_or_template_id
      }
      new_event[:username] = event.username unless event.username.blank?

      # Fill in the dest information if we have it
      unless dest_event.nil?
        # Determine from which field to get the dest information
        dest_key = dest_event.dest_vm_name.nil? ? '' : 'dest_'

        new_event.merge!(
          :dest_host_name         => dest_event.host_name,
          :dest_host_id           => dest_event.host_id,
          :dest_vm_name           => dest_event.send("#{dest_key}vm_name"),
          :dest_vm_location       => dest_event.send("#{dest_key}vm_location"),
          :dest_vm_or_template_id => dest_event.send("#{dest_key}vm_or_template_id")
        )
      end

      create_event(new_event)
    end
  end

  def get_refresh_target(target_type)
    m = "#{target_type}_refresh_target"
    self.respond_to?(m) ? send(m) : nil
  end

  def vm_refresh_target
    (vm_or_template && vm_or_template.ext_management_system ? vm_or_template : host_refresh_target)
  end
  alias_method :src_vm_refresh_target, :vm_refresh_target

  def host_refresh_target
    (host && host.ext_management_system ? host : ems_refresh_target)
  end
  alias_method :src_host_refresh_target, :host_refresh_target

  def dest_vm_refresh_target
    (dest_vm_or_template && dest_vm_or_template.ext_management_system ? dest_vm_or_template : dest_host_refresh_target)
  end

  def dest_host_refresh_target
    (dest_host && dest_host.ext_management_system ? dest_host : ems_refresh_target)
  end

  def ems_cluster_refresh_target
    ext_management_system
  end
  alias_method :src_ems_cluster_refresh_target, :ems_cluster_refresh_target

  def ems_refresh_target
    ext_management_system
  end

  #
  # Purging methods
  #

  def self.keep_ems_events
    VMDB::Config.new("vmdb").config.fetch_path(:ems_events, :history, :keep_ems_events)
  end

  def self.purge_date
    keep = keep_ems_events.to_i_with_method.seconds
    keep = 6.months if keep == 0
    keep.ago.utc
  end

  def self.purge_window_size
    VMDB::Config.new("vmdb").config.fetch_path(:ems_events, :history, :purge_window_size) || 1000
  end

  def self.purge_timer
    purge_queue(purge_date)
  end

  def self.purge_queue(ts)
    MiqQueue.put(
      :class_name  => name,
      :method_name => "purge",
      :role        => "event",
      :queue_name  => "ems",
      :args        => [ts],
    )
  end

  def self.purge(older_than, window = nil, limit = nil)
    _log.info("Purging #{limit || "all"} events older than [#{older_than}]...")

    window ||= purge_window_size

    total = where(arel_table[:timestamp].lteq(older_than)).delete_in_batches(window, limit) do |count, _total|
      _log.info("Purging #{count} events.")
    end

    _log.info("Purging #{limit || "all"} events older than [#{older_than}]...Complete - Deleted #{total} records")
  end
end
