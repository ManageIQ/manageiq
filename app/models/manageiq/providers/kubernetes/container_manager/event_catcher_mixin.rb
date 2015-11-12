module ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcherMixin
  extend ActiveSupport::Concern
  ENABLED_EVENTS = {
    'Node' => %w(NodeReady NodeNotReady rebooted),
    'Pod'  => %w(scheduled failedScheduling failedValidation HostPortConflict created failed started killing)
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
    # TODO: since event_monitor_handle is returning only events that
    # are generated starting from this moment we need to pull the
    # entire # inventory to make sure that it's up-to-date.
    event_monitor_running
    event_monitor_handle.each do |event|
      # Sleeping here is not necessary because the events are delivered
      # asynchronously when available.
      @queue.enq event
    end
  ensure
    reset_event_monitor_handle
  end

  def process_event(event)
    event_data = {
      :timestamp => event.object.lastTimestamp,
      :kind      => event.object.involvedObject.kind,
      :name      => event.object.involvedObject.name,
      :namespace => event.object.involvedObject['table'][:namespace],
      :reason    => event.object.reason,
      :message   => event.object.message
    }

    unless event.object.involvedObject.fieldPath.nil?
      event_data[:fieldpath] = event.object.involvedObject.fieldPath
    end

    supported_reasons = ENABLED_EVENTS[event_data[:kind]] || []

    unless supported_reasons.include?(event_data[:reason])
      _log.debug "#{log_prefix} Discarding event [#{event_data}]"
      return
    end

    event_data[:event_type] = "#{event_data[:kind].upcase}_" \
                              "#{event_data[:reason].upcase}"

    # Handle event data for specific entities
    case event_data[:kind]
    when 'Node'
      event_data[:container_node_name] = event_data[:name]
    when 'Pod'
      /^spec.containers{(?<container_name>.*)}$/ =~ event_data[:fieldpath]
      unless container_name.nil?
        event_data[:event_type] = "CONTAINER_#{event_data[:reason].upcase}"
        event_data[:container_name] = container_name
      end
      event_data[:container_group_name] = event_data[:name]
      event_data[:container_namespace] = event_data[:namespace]
    end

    _log.info "#{log_prefix} Queuing event [#{event_data}]"
    EmsEvent.add_queue('add_kubernetes', @cfg[:ems_id], event_data)
  end
end
