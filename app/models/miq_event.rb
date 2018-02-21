class MiqEvent < EventStream
  CHILD_EVENTS = {
    :assigned_company_tag   => {
      :Host         => [:vms_and_templates],
      :EmsCluster   => [:all_vms_and_templates],
      :Storage      => [:vms_and_templates],
      :ResourcePool => [:vms_and_templates]
    },
    :unassigned_company_tag => {
      :Host         => [:vms_and_templates],
      :EmsCluster   => [:all_vms_and_templates],
      :Storage      => [:vms_and_templates],
      :ResourcePool => [:vms_and_templates]
    }
  }

  SUPPORTED_POLICY_AND_ALERT_CLASSES = [Host, VmOrTemplate, Storage,
                                        EmsCluster, ResourcePool, MiqServer,
                                        ExtManagementSystem,
                                        ContainerReplicator, ContainerGroup, ContainerProject,
                                        ContainerNode, ContainerImage, PhysicalServer].freeze

  def self.raise_evm_event(target, raw_event, inputs = {}, options = {})
    # Target may have been deleted if it's a worker
    # Target, in that case will be the worker's server.
    # The generic raw_event remains, but client can pass the :type of the worker spawning the event:
    #  ex: MiqEvent.raise_evm_event(w.miq_server, "evm_worker_not_responding", :type => "MiqGenericWorker", :event_details => "MiqGenericWorker with pid 1234 killed due to not responding")
    # Policy, automate, and alerting could then consume this type field along with the details
    if target.kind_of?(Array)
      klass, id = target
      target = klass.to_s.constantize.find_by(:id => id)
    end
    raise "Unable to find object for target: [#{target}]" unless target

    event = normalize_event(raw_event.to_s)
    if event == 'unknown' && target.class.base_class.in?(SUPPORTED_POLICY_AND_ALERT_CLASSES)
      _log.warn("Event #{raw_event} for class [#{target.class.name}] id [#{target.id}] was not raised: #{raw_event} is not defined in MiqEventDefinition")
      _log.info("Alert for Event [#{raw_event}]")
      MiqAlert.evaluate_alerts(target, raw_event, inputs) if MiqAlert.event_alertable?(raw_event)
      return
    end

    event_obj = build_evm_event(event, target)
    inputs.merge!('MiqEvent::miq_event' => event_obj.id, :miq_event_id => event_obj.id)
    inputs.merge!('EventStream::event_stream' => event_obj.id, :event_stream_id => event_obj.id)

    # save the EmsEvent that are required by some actions later in policy resolution
    event_obj.update_attributes(:full_data => {:source_event_id => inputs[:ems_event].id}) if inputs[:ems_event]

    MiqAeEvent.raise_evm_event(raw_event, target, inputs, options)
    event_obj
  end

  def process_evm_event(inputs = {})
    _log.info("target = [#{target.inspect}]")
    return if target.nil?

    return unless target.class.base_class.in?(SUPPORTED_POLICY_AND_ALERT_CLASSES)
    raise "Unable to find object with class: [#{target_class}], Id: [#{target_id}]" unless target

    results = {}
    inputs[:type] ||= target.class.name
    inputs[:source_event] = source_event if source_event

    _log.info("Event Raised [#{event_type}]")
    begin
      results[:policy] = MiqPolicy.enforce_policy(target, event_type, inputs)
      update_with_policy_result(results)
      update_attributes(:message => 'Policy resolved successfully!')
    rescue MiqException::PolicyPreventAction => err
      update_attributes(:full_data => {:policy => {:prevented => true}}, :message => err.message)
    end

    _log.info("Alert for Event [#{event_type}]")
    results[:alert] = MiqAlert.evaluate_alerts(target, event_type, inputs)

    results[:children_events] = self.class.raise_event_for_children(target, event_type, inputs)

    results
  end

  def self.build_evm_event(event, target)
    options = {
      :event_type => event,
      :target     => target,
      :source     => 'POLICY',
      :timestamp  => Time.now.utc
    }
    user = User.current_user
    options.merge!(:user_id => user.id, :group_id => user.current_group.id, :tenant_id => user.current_tenant.id) if user
    MiqEvent.create(options)
  end

  def update_with_policy_result(result = {})
    update_attributes(
      :full_data => {
        :policy => {
          :actions => {
            :assign_scan_profile => result.fetch_path(:policy, :actions, :assign_scan_profile)
          }
        }
      }
    ) if result.fetch_path(:policy, :actions, :assign_scan_profile)
  end

  def self.normalize_event(event)
    return event if MiqEventDefinition.find_by(:name => event)
    "unknown"
  end

  def self.raise_evm_event_queue_in_region(target, raw_event, inputs = {})
    MiqQueue.put(
      :zone        => nil,
      :class_name  => name,
      :method_name => 'raise_evm_event',
      :args        => [[target.class.name, target.id], raw_event, inputs]
    )
  end

  def self.raise_evm_event_queue(target, raw_event, inputs = {})
    MiqQueue.put(
      :class_name  => name,
      :method_name => 'raise_evm_event',
      :args        => [[target.class.name, target.id], raw_event, inputs]
    )
  end

  def self.raise_evm_alert_event_queue(target, raw_event, inputs = {})
    MiqQueue.put_unless_exists(
      :class_name  => "MiqAlert",
      :method_name => 'evaluate_alerts',
      :args        => [[target.class.name, target.id], raw_event, inputs]
    ) if MiqAlert.alarm_has_alerts?(raw_event)
  end

  def self.raise_evm_job_event(target, options = {}, inputs = {}, q_options = {})
    # Eg. options = {:type => "scan", ":prefix => "request, :suffix => "abort"}
    options.reverse_merge!(
      :type   => "scan",
      :prefix => nil,
      :suffix => nil
    )

    target_model = target.class.base_model.name.downcase
    target_model = "vm" if target_model.match("template")

    base_event = [target_model, options[:type]].join("_")
    evm_event  = [options[:prefix], base_event, options[:suffix]].compact.join("_")
    raise_evm_event(target, evm_event, inputs, q_options)
  end

  def self.raise_event_for_children(target, raw_event, inputs = {})
    child_assocs = CHILD_EVENTS.fetch_path(raw_event.to_sym, target.class.base_class.name.to_sym)
    return if child_assocs.blank?

    child_event = "#{raw_event}_parent_#{target.class.base_model.name.underscore}"
    child_assocs.each do |assoc|
      next unless target.respond_to?(assoc)
      children = target.send(assoc)
      children.each do |child|
        _log.info("Raising Event [#{child_event}] for Child [(#{child.class}) #{child.name}] of Parent [(#{target.class}) #{target.name}]")
        raise_evm_event_queue(child, child_event, inputs)
      end
    end
  end

  def self.event_name_for_target(target, event_suffix)
    "#{target.class.base_model.name.underscore}_#{event_suffix}"
  end

  # return the event that triggered the policy event
  def source_event
    return @source_event if @source_event
    return unless full_data

    source_event_id = full_data.fetch_path(:source_event_id)
    @source_event = EventStream.find_by(:id => source_event_id) if source_event_id
  end
end
