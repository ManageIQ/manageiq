require 'workers/event_catcher'
require 'json'

class EventCatcherAmazon < EventCatcher
  def event_monitor_handle
    require 'Amazon/events/amazon_event_monitor'
    unless @event_monitor_handle
      aws_access_key_id     = @ems.authentication_userid
      aws_secret_access_key = @ems.authentication_password
      aws_region            = @ems.provider_region
      queue_id              = @ems.guid
      @event_monitor_handle = AmazonEventMonitor.new(aws_access_key_id, aws_secret_access_key, aws_region, queue_id)
    end
    @event_monitor_handle
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
      $log.debug("#{log_prefix} Received events #{events.collect(&:message)}") if $log.debug?
      @queue.enq events
      sleep_poll_normal
    end
  ensure
    reset_event_monitor_handle
  end

  def process_event(event)
    if filtered?(event)
      $log.info "#{log_prefix} Skipping filtered Amazon event [#{event["messageId"]}]"
    else
      $log.info "#{log_prefix} Caught event [#{event["messageId"]}]"
      EmsEvent.add_queue('add_amazon', @cfg[:ems_id], event)
    end
  end

  def filtered?(event)
    filtered_events.include?(event["messageType"])
  end
end
