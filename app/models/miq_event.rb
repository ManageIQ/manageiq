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

  SUPPORTED_POLICY_AND_ALERT_CLASSES = [Host, VmOrTemplate, Storage, EmsCluster, ResourcePool, MiqServer]

  def self.raise_evm_event(target, raw_event, inputs={})
    # Target may have been deleted if it's a worker
    # Target, in that case will be the worker's server.
    # The generic raw_event remains, but client can pass the :type of the worker spawning the event:
    #  ex: MiqEvent.raise_evm_event(w.miq_server, "evm_worker_not_responding", :type => "MiqGenericWorker", :event_details => "MiqGenericWorker with pid 1234 killed due to not responding")
    # Policy, automate, and alerting could then consume this type field along with the details
    if target.kind_of?(Array)
      klass, id = target
      klass = Object.const_get(klass)
      target = klass.find_by_id(id)
      raise "Unable to find object with class: [#{klass}], Id: [#{id}]" unless target
    end

    inputs[:type] ||= target.class.name

    # TODO: Need to be able to pick an event without an expression in the UI
    event = normalize_event(raw_event.to_s)

    # Determine what actions to perform for this event
    actions = event_to_actions(target, raw_event, event)

    results = {}

    if actions[:enforce_policy]
      _log.info("Event Raised [#{event}]")
      results[:policy] = MiqPolicy.enforce_policy(target, event, inputs)
    end

    if actions[:raise_to_automate]
      _log.info("Event [#{raw_event}] raised to automation")
      results[:automate] = MiqAeEvent.raise_evm_event(raw_event, target, inputs)
    end

    if actions[:evaluate_alert]
      _log.info("Alert for Event [#{raw_event}]")
      results[:alert] = MiqAlert.evaluate_alerts(target, event, inputs)
    end

    if actions[:raise_children_events]
      results[:children_events] = raise_event_for_children(target, raw_event, inputs)
    end

    results
  end

  def self.event_to_actions(target, raw_event, event)
    # Old logic:
    #
    # For Host, VmOrTemplate, Storage, EmsCluster, ResourcePool targets:
    #   if it's a known event, we enforce policy and evaluate alerts
    #   if not known but alertable???, we only evaluate alerts
    #   For any of these targets, we then raise an event for the children of the target
    # For any other targets, we raise an raise an event to automate

    # New logic:
    #   Known events:
    #     send to policy (policy can then raise to automate)
    #     evaluate alerts
    #     raise for children
    #   Unknown events:
    #     Alert for ones we care about
    #     raise for children
    #   Not Host, VmOrTemplate, Storage, EmsCluster, ResourcePool events:
    #     Alert if event is alertable
    #     raise to automate (since policy doesn't support these types)

    # TODO: Need to add to automate_expressions in MiqAlert line 345 for alertable events
    actions = Hash.new(false)
    if target.class.base_class.in?(SUPPORTED_POLICY_AND_ALERT_CLASSES)
      actions[:raise_children_events] = true
      if event != "unknown"
        actions[:enforce_policy] = true
        actions[:evaluate_alert] = true
      elsif MiqAlert.event_alertable?(raw_event)
        actions[:evaluate_alert] = true
      else
        _log.debug("Event [#{raw_event}] does not participate in policy enforcement")
      end
    else
      actions[:raise_to_automate] = true
      actions[:evaluate_alert] = true if MiqAlert.event_alertable?(raw_event)
    end
    actions
  end

  def self.raise_evm_event_queue_in_region(target, raw_event, inputs={})
    MiqQueue.put(
      :zone        => nil,
      :class_name  => self.name,
      :method_name => 'raise_evm_event',
      :args        => [[target.class.name, target.id], raw_event, inputs]
    )
  end

  def self.raise_evm_event_queue(target, raw_event, inputs={})
    MiqQueue.put(
      :class_name  => self.name,
      :method_name => 'raise_evm_event',
      :args        => [[target.class.name, target.id], raw_event, inputs]
    )
  end

  def self.raise_evm_alert_event_queue(target, raw_event, inputs={})
    MiqQueue.put_unless_exists(
      :class_name  => "MiqAlert",
      :method_name => 'evaluate_alerts',
      :args        => [[target.class.name, target.id], raw_event, inputs]
    ) if MiqAlert.alarm_has_alerts?(raw_event)
  end

  def self.raise_evm_job_event(target, options = {}, inputs={})
    # Eg. options = {:type => "scan", ":prefix => "request, :suffix => "abort"}
    options.reverse_merge!(
      :type   => "scan",
      :prefix => nil,
      :suffix => nil
    )
    base_event = [target.class.base_model.name.downcase, options[:type]].join("_")
    evm_event  = [options[:prefix], base_event, options[:suffix]].compact.join("_")
    self.raise_evm_event(target, evm_event, inputs)
  end

  def self.raise_event_for_children(target, raw_event, inputs={})
    child_assocs = CHILD_EVENTS.fetch_path(raw_event.to_sym, target.class.base_class.name.to_sym)
    return if child_assocs.blank?

    child_event = "#{raw_event}_parent_#{target.class.base_model.name.underscore}"
    child_assocs.each do |assoc|
      next unless target.respond_to?(assoc)
      children = target.send(assoc)
      children.each do |child|
        _log.info("Raising Event [#{child_event}] for Child [(#{child.class}) #{child.name}] of Parent [(#{target.class}) #{target.name}]")
        self.raise_evm_event_queue(child, child_event, inputs)
      end
    end
  end

  def self.normalize_event(event)
    return event if MiqEventDefinition.find_by_name(event)
    return "unknown"
  end

  def self.event_name_for_target(target, event_suffix)
    "#{target.class.base_model.name.underscore}_#{event_suffix}"
  end
end
