module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::EventCatcher::Runner
  def stop_event_monitor
    event_monitor_handle.stop
  end

  def monitor_events
    event_monitor_handle.start
    event_monitor_running
    event_monitor_handle.poll do |event|
      _log.debug { "#{log_prefix} Received event #{event.id}" }
      @queue.enq event
    end
  ensure
    stop_event_monitor
  end

  def queue_event(event)
    _log.info "#{log_prefix} Caught event [#{event.id}]"
    event_hash = provider_module::AutomationManager::EventParser.event_to_hash(event, @cfg[:ems_id])
    EmsEvent.add_queue('add', @cfg[:ems_id], event_hash)
  end

  private

  def provider_module
    ManageIQ::Providers::Inflector.provider_module(self.class)
  end

  def event_monitor_handle
    @event_monitor_handle ||= begin
      provider_module::AutomationManager::EventCatcher::Stream.new(
        @ems,
        :poll_sleep => worker_settings[:poll]
      )
    end
  end
end
