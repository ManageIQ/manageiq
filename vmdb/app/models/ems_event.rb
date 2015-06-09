class EmsEvent < ActiveRecord::Base
  serialize :full_data

  belongs_to :ext_management_system, :foreign_key => :ems_id

  belongs_to :vm_or_template
  alias src_vm_or_template vm_or_template
  belongs_to :vm,           :foreign_key => :vm_or_template_id
  belongs_to :miq_template, :foreign_key => :vm_or_template_id
  belongs_to :host
  belongs_to :availability_zone
  alias src_host host

  belongs_to :dest_vm_or_template, :class_name => "VmOrTemplate"
  belongs_to :dest_vm,             :class_name => "Vm",          :foreign_key => :dest_vm_or_template_id
  belongs_to :dest_miq_template,   :class_name => "MiqTemplate", :foreign_key => :dest_vm_or_template_id
  belongs_to :dest_host,           :class_name => "Host"

  belongs_to :service

  include_concern 'Automate'
  include ReportableMixin

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
    begin
      EmsEventHelper.new(self).handle
    rescue => err
      $log.log_backtrace(err)
    end
  end

  def self.task_final_events
    return VMDB::Config.new('event_handling').config[:task_final_events]
  end

  def self.event_groups
    return VMDB::Config.new('event_handling').config[:event_groups]
  end

  def self.bottleneck_event_groups
    return VMDB::Config.new('event_handling').config[:bottleneck_event_groups]
  end

  def self.filtered_events
    return VMDB::Config.new('event_handling').config[:filtered_events]
  end

  def self.group_and_level(event_type)
    group, v = self.event_groups.find { |k, v| v[:critical].include?(event_type) || v[:detail].include?(event_type) }
    if group.nil?
      group, level = :other, :detail
    else
      level = v[:detail].include?(event_type) ? :detail : :critical
    end
    return group, level
  end

  def self.group_name(group)
    return nil if group.nil?
    group = self.event_groups[group.to_sym]
    return nil if group.nil?
    return group[:name]
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
    self.add(ems_id, EmsEvent::Parsers::Vc.event_to_hash(event, ems_id))
  end

  def self.add_rhevm(ems_id, event)
    self.add(ems_id, EmsEvent::Parsers::Rhevm.event_to_hash(event, ems_id))
  end

  def self.add_openstack(ems_id, event)
    self.add(ems_id, EmsEvent::Parsers::Openstack.event_to_hash(event, ems_id))
  end

  def self.add_openstack_infra(ems_id, event)
    self.add(ems_id, EmsEvent::Parsers::OpenstackInfra.event_to_hash(event, ems_id))
  end

  def self.add_amazon(ems_id, event)
    self.add(ems_id, EmsEvent::Parsers::Amazon.event_to_hash(event, ems_id))
  end

  def self.add_kubernetes(ems_id, event)
    add(ems_id, EmsEvent::Parsers::Kubernetes.event_to_hash(event, ems_id))
  end

  def self.add(ems_id, event_hash)
    event_type = event_hash[:event_type]
    raise MiqException::Error, "event_type must be set in event" if event_type.nil?

    event_hash[:ems_id] = ems_id
    process_vm_in_event!(event_hash)
    process_vm_in_event!(event_hash, :prefix => "dest_")
    process_host_in_event!(event_hash)
    process_host_in_event!(event_hash, :prefix => "dest_")
    process_availability_zone_in_event!(event_hash)
    process_cluster_in_event!(event_hash)

    return if events_filtered?(event_hash, self.filtered_events[event_type.to_sym])

    # Write the event
    new_event = create_event(event_hash)

    # Create a 'completed task' event if this is the last in a series of events
    create_completed_event(event_hash) if task_final_events.has_key?(event_type.to_sym)

    return new_event
  end

  FILTER_KEYS = [
      # Filter Key | Event Key             | Object Description
      #========================================================
      ['ems',       :ems_id,                 "EMS"             ],
      ['src_vm',    :vm_or_template_id,      "source VM"       ],
      ['dest_vm',   :dest_vm_or_template_id, "dest VM"         ],
      ['src_host',  :host_id,                "source Host"     ],
      ['dest_host', :dest_host_id,           "dest Host"       ]
  ]

  def self.events_filtered?(event_hash, filter)
    return false if filter.nil?

    log_prefix = "MIQ(EmsEvent.events_filtered?) Skipping caught event [#{event_hash[:event_type]}] chainId [#{event_hash[:chain_id]}]"
    FILTER_KEYS.each do |filter_key, event_key, object_description|
      if event_filtered?(event_hash, event_key, filter, filter_key)
        $log.info "#{log_prefix} for #{object_description} [#{event_hash[event_key]}]"
        return true
      end
    end

    return false
  end

  def self.event_filtered?(event_hash, event_hash_key, filter, filter_key)
    filter.has_key?(filter_key) && filter[filter_key].include?(event_hash[event_hash_key])
  end

  def self.process_object_in_event!(klass, event, options = {})
    prefix      = options[:prefix]
    key_prefix  = options[:key_prefix]  || klass.name.underscore
    id_key      = options[:id_key]      || "#{prefix}#{key_prefix}_id".to_sym
    ems_ref_key = options[:ems_ref_key] || "#{prefix}#{key_prefix}_ems_ref".to_sym
    name_key    = options[:name_key]    || "#{prefix}#{key_prefix}_name".to_sym

    if event[id_key].nil?
      ems_ref = event[ems_ref_key]
      object  = klass.base_class.find_by_ems_ref_and_ems_id(ems_ref, event[:ems_id]) unless ems_ref.nil?

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
        event[:vm_name]         ||= vm.name
      end
    end
  end

  def self.process_host_in_event!(event, options = {})
    process_object_in_event!(Host, event, options)
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
    @first_chained_event ||= EmsEvent.first_chained_event(self.ems_id, self.chain_id) || self
  end

  def group
    return @group unless @group.nil?
    @group, @group_level = self.class.group_and_level(self.event_type)
    return @group
  end

  def group_level
    return @group_level unless @group_level.nil?
    @group, @group_level = self.class.group_and_level(self.event_type)
    return @group_level
  end

  def group_name
    @group_name ||= self.class.group_name(self.group)
  end

  def get_target(target_type)
    target_type = target_type.to_s
    if target_type =~ /^first_chained_(.+)$/
      target_type = $1
      event = self.first_chained_event
    else
      event = self
    end

    target_type = "src_vm_or_template"  if target_type == "src_vm"
    target_type = "dest_vm_or_template" if target_type == "dest_vm"

    event.send(target_type)
  end

  private

  def self.create_event(event)
    event.delete_if { |k, | k.to_s.ends_with?("_ems_ref") }

    new_event = EmsEvent.create(event) unless EmsEvent.exists?(
      {
        :event_type => event[:event_type],
        :timestamp => event[:timestamp],
        :chain_id => event[:chain_id],
        :ems_id => event[:ems_id]
      }
    )
    new_event.handle_event if new_event
    return new_event
  end

  def self.create_completed_event(event, orig_task=nil)
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
        :event_type => new_event_type,
        :chain_id => event.chain_id,
        :is_task => true,
        :source => 'EVM',
        :ems_id => event.ems_id,

        :message => "#{orig_task.event_type} Completed",
        :timestamp => event.timestamp,

        :host_name => source_event.host_name,
        :host_id => source_event.host_id,
        :vm_name => source_event.vm_name,
        :vm_location => source_event.vm_location,
        :vm_or_template_id => source_event.vm_or_template_id
      }
      new_event[:username] = event.username unless event.username.blank?

      # Fill in the dest information if we have it
      unless dest_event.nil?
        # Determine from which field to get the dest information
        dest_key = dest_event.dest_vm_name.nil? ? '' : 'dest_'

        new_event.merge!(
          :dest_host_name => dest_event.host_name,
          :dest_host_id => dest_event.host_id,
          :dest_vm_name => dest_event.send("#{dest_key}vm_name"),
          :dest_vm_location => dest_event.send("#{dest_key}vm_location"),
          :dest_vm_or_template_id => dest_event.send("#{dest_key}vm_or_template_id")
        )
      end

      create_event(new_event)
    end
  end

  def get_refresh_target(target_type)
    m = "#{target_type}_refresh_target"
    self.respond_to?(m) ? self.send(m) : nil
  end

  def vm_refresh_target
    return (vm_or_template && vm_or_template.ext_management_system ? vm_or_template : host_refresh_target)
  end
  alias src_vm_refresh_target vm_refresh_target

  def host_refresh_target
    return (host && host.ext_management_system ? host : ems_refresh_target)
  end
  alias src_host_refresh_target host_refresh_target

  def dest_vm_refresh_target
    return (dest_vm_or_template && dest_vm_or_template.ext_management_system ? dest_vm_or_template : dest_host_refresh_target)
  end

  def dest_host_refresh_target
    return (dest_host && dest_host.ext_management_system ? dest_host : ems_refresh_target)
  end

  def ems_cluster_refresh_target
    return ext_management_system
  end
  alias src_ems_cluster_refresh_target ems_cluster_refresh_target

  def ems_refresh_target
    return ext_management_system
  end

  #
  # Purging methods
  #

  def self.purge_date
    (VMDB::Config.new("vmdb").config.fetch_path(:ems_events, :history, :keep_ems_events) || 6.months).to_i_with_method.ago.utc
  end

  def self.purge_window_size
    VMDB::Config.new("vmdb").config.fetch_path(:ems_events, :history, :purge_window_size) || 1000
  end

  def self.purge_timer
    purge_queue(purge_date)
  end

  def self.purge_queue(ts)
    MiqQueue.put_or_update(
      :class_name  => self.name,
      :method_name => "purge",
      :role        => "event",
      :queue_name  => "ems"
    ) { |msg, item| item.merge(:args => [ts]) }
  end

  def self.purge(older_than, window = nil, limit = nil)
    log_header = "MIQ(#{self.name}.purge)"
    $log.info("#{log_header} Purging #{limit.nil? ? "all" : limit} events older than [#{older_than}]...")

    window ||= purge_window_size

    oldest = self.select(:timestamp).order(:timestamp).first
    oldest = oldest.nil? ? older_than : oldest.timestamp

    total = 0
    until (batch = self.all(:select => :id, :conditions => {:timestamp => oldest..older_than}, :limit => window)).empty?
      ids = batch.collect(&:id)
      ids = ids[0, limit - total] if limit && total + ids.length > limit

      $log.info("#{log_header} Purging #{ids.length} events.")
      total += self.delete_all(:id => ids)

      break if limit && total >= limit
    end

    $log.info("#{log_header} Purging #{limit.nil? ? "all" : limit} events older than [#{older_than}]...Complete - Deleted #{total} records")
  end
end
