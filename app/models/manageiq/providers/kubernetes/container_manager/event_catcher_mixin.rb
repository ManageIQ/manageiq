module ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcherMixin
  extend ActiveSupport::Concern

  # https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/container/event.go
  # 'Created', 'Failed', 'Started', 'Killing', 'Stopped' and 'Unhealthy' are in fact container related events,
  # returned as part of a pod event.
  ENABLED_EVENTS = {
    'Node'                  => %w(NodeReady NodeNotReady Rebooted NodeSchedulable NodeNotSchedulable InvalidDiskCapacity
                                  FailedMount),
    'Pod'                   => %w(Scheduled FailedScheduling FailedValidation HostPortConflict DeadlineExceeded
                                  OutOfDisk NodeSelectorMismatching InsufficientFreeCPU
                                  InsufficientFreeMemory Created Failed Started Killing Stopped Unhealthy),
    'ReplicationController' => %w(SuccessfulCreate FailedCreate)
  }

  def event_monitor_handle
    require 'kubernetes/events/kubernetes_event_monitor'
    @event_monitor_handle ||= KubernetesEventMonitor.new(@ems)
  end

  def reset_event_monitor_handle
    @event_monitor_handle = nil
  end

  def stop_event_monitor
    @event_monitor_handle.stop unless @event_monitor_handle.nil?
  rescue => err
    _log.error("#{log_prefix} Event Monitor error [#{err.message}]")
    _log.error("#{log_prefix} Error details: [#{err.details}]")
    _log.log_backtrace(err)
  ensure
    reset_event_monitor_handle
  end

  def monitor_events
    event_monitor_handle.start
    event_monitor_running
    # TODO: since event_monitor_handle is returning only events that
    # are generated starting from this moment we need to pull the
    # entire # inventory to make sure that it's up-to-date.
    event_monitor_handle.each do |event|
      # Sleeping here is not necessary because the events are delivered
      # asynchronously when available.
      @queue.enq event
    end
  ensure
    reset_event_monitor_handle
  end

  def queue_event(event)
    event_data = extract_event_data(event)
    _log.info "#{log_prefix} Queuing event [#{event_data}]"
    event_hash = ManageIQ::Providers::Kubernetes::ContainerManager::EventParser.event_to_hash(event_data, @cfg[:ems_id])
    EmsEvent.add_queue('add', @cfg[:ems_id], event_hash)
  end

  def filtered?(event)
    parsed_event = extract_event_data(event)
    parsed_event.nil? || filtered_events.include?(parsed_event[:event_type])
  end

  # Returns hash, or nil if event should be discarded.
  def extract_event_data(event)
    kind = event.object.involvedObject.kind
    reason = event.object.reason
    supported_reasons = ENABLED_EVENTS[kind] || []
    return unless supported_reasons.include?(reason)

    event_data = {
      :timestamp => event.object.lastTimestamp,
      :kind      => kind,
      :name      => event.object.involvedObject.name,
      :namespace => event.object.involvedObject['table'][:namespace],
      :reason    => reason,
      :message   => event.object.message,
      :uid       => event.object.involvedObject.uid
    }

    unless event.object.involvedObject.fieldPath.nil?
      event_data[:fieldpath] = event.object.involvedObject.fieldPath
    end

    event_type_prefix = kind.upcase

    # Handle event data for specific entities
    case kind
    when 'Node'
      event_data[:container_node_name] = event_data[:name]
      # Workaround for missing/useless node UID (#9600, https://github.com/kubernetes/kubernetes/issues/29289)
      if event_data[:uid].nil? || event_data[:uid] == event_data[:name]
        node = ContainerNode.find_by(:ems_id => @ems.id, :name => event_data[:name])
        event_data[:uid] = node.try!(:ems_ref)
      end
    when 'Pod'
      /^spec.containers{(?<container_name>.*)}$/ =~ event_data[:fieldpath]
      unless container_name.nil?
        event_type_prefix = "CONTAINER"
        event_data[:container_name] = container_name
      end
      event_data[:container_group_name] = event_data[:name]
      event_data[:container_namespace] = event_data[:namespace]
    when 'ReplicationController'
      event_type_prefix = "REPLICATOR"
      event_data[:container_replicator_name] = event_data[:name]
      event_data[:container_namespace] = event_data[:namespace]
    end

    event_data[:event_type] = "#{event_type_prefix}_#{reason.upcase}"

    event_data
  end
end
