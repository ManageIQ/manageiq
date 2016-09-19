class ManageIQ::Providers::Openshift::ContainerManager::EventCatcherHawkular::Runner <
  ManageIQ::Providers::BaseManager::EventCatcher::Runner

  TAG_EVENT_TYPE    = "miq.event_type".freeze # required by fetch
  TAG_RESOURCE_TYPE = "miq.resource_type".freeze # optionally provided when linking to a resource

  def initialize(cfg = {})
    super

    # Supported event_types (see settings.yml)
    @whitelist = [
      # summary
      'hawkular_datasource.error',
      'hawkular_datasource_remove.error',
      'hawkular_deployment.error',
      'hawkular_deployment_remove.error',
      'hawkular_event.critical', # general purpose critical/summary level event
      # detail
      'hawkular_datasource.ok',
      'hawkular_datasource_remove.ok',
      'hawkular_deployment.ok',
      'hawkular_deployment_remove.ok',
      'hawkular_event' # # general purpose detail level event
    ].to_set.freeze
  end

  def reset_event_monitor_handle
    @event_monitor_handle = nil
  end

  def stop_event_monitor
    @event_monitor_handle.try(:stop)
  ensure
    reset_event_monitor_handle
  end

  def monitor_events
    event_monitor_handle.start
    event_monitor_handle.each_batch do |events|
      event_monitor_running
      #byebug_term
      events.each do |e|
        e.tags = {"miq.event_type" => "hawkular_event", "miq.resource_type" => "MiddlewareServer"}
      end
      new_events = events.select { |e| whitelist?(e) }
      $mw_log.debug("#{log_prefix} Discarding events #{events - new_events}") if new_events.length < events.length
      if new_events.any?
        $mw_log.debug "#{log_prefix} Queueing events #{new_events}"
        @queue.enq new_events
      end
      # invoke the configured sleep before the next event fetch
      sleep_poll_normal
    end
  ensure
    reset_event_monitor_handle
  end

  def process_event(event)
    $mw_log.debug "Processing Event #{event}"
    event_hash = event_to_hash(event, @cfg[:ems_id])
    #byebug_term

    if blacklist?(event_hash[:event_type])
      $mw_log.debug "#{log_prefix} Filtering blacklisted event [#{event}]"
    else
      $mw_log.debug "#{log_prefix} Adding ems event [#{event_hash}]"
      EmsEvent.add_queue('add', @cfg[:ems_id], event_hash)
    end
  end

  private

  def event_monitor_handle
    @event_monitor_handle ||= ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher::Stream.new(@ems)
  end

  def whitelist?(event)
    tags = event.tags
    return false unless tags
    event_type = tags[TAG_EVENT_TYPE]
    event_type && @whitelist.include?(event_type)
  end

  def blacklist?(event_type)
    filtered_events.include?(event_type)
  end

  def event_to_hash(event, ems_id = nil)
    #byebug_term
    event.event_type = event.tags[TAG_EVENT_TYPE]
    if event.context
      event.message        = event.context['message'] # optional, prefer context message if provided
      event.middleware_ref = event.context['resource_path'] # optional context for linking to resource
    end
    event.message ||= event.text
    event.middleware_type = event.tags[TAG_RESOURCE_TYPE] # optional tag for linking to resource
    {
      :ems_id          => ems_id,
      :source          => 'HAWKULAR',
      :timestamp       => Time.zone.at(event.ctime / 1000),
      :event_type      => event.event_type,
      :message         => event.message,
      :middleware_ref  => event.middleware_ref,
      :middleware_type => event.middleware_type,
      :full_data       => event.to_s
    }
  end
end
