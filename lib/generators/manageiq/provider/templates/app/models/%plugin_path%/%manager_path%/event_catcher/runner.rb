class <%= class_name %>::<%= manager_type %>::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner
  def stop_event_monitor
    event_monitor_handle.stop
  end

  def monitor_events
    event_monitor_handle.start
    event_monitor_running
    event_monitor_handle.poll do |event|
      @queue.enq event
    end
  ensure
    stop_event_monitor
  end

  def queue_event(event)
    _log.info "#{log_prefix} Caught event [#{event[:id]}]"
    event_hash = event_to_hash(event, @cfg[:ems_id])
    EmsEvent.add_queue('add', @cfg[:ems_id], event_hash)
  end

  private

  def event_to_hash(event, ems_id)
    {
      :event_type => "<%= provider_name.upcase %>#{event[:name]}",
      :source     => '<%= provider_name.upcase %>',
      :timestamp  => event[:timestamp],
      :vm_ems_ref => event[:vm_ems_ref],
      :full_data  => event,
      :ems_id     => ems_id
    }
  end

  def event_monitor_handle
    @event_monitor_handle ||= begin
      self.class.parent::Stream.new(
        @ems,
        :poll_sleep => worker_settings[:poll]
      )
    end
  end
end
