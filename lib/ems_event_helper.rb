class EmsEventHelper
  include Vmdb::Logging

  def initialize(event)
    raise ArgumentError, "event must be an EmsEvent" unless event.kind_of?(EmsEvent)
    @event = event
  end

  def handle
    before_handle

    handle_automation_event
    handle_alert_event

    after_handle
  end

  def before_handle
    _log.info("Processing EMS event [#{@event.event_type}] chain_id [#{@event.chain_id}] on EMS [#{@event.ems_id}]...")
  end

  def after_handle
    _log.info("Processing EMS event [#{@event.event_type}] chain_id [#{@event.chain_id}] on EMS [#{@event.ems_id}]...Complete")
  end

  def handle_automation_event
    MiqAeEvent.raise_ems_event(@event)
  rescue => err
    _log.log_backtrace(err)
  end

  def handle_alert_event
    @event.policy("src_vm", @event.event_type) if MiqAlert.event_alertable?(@event.event_type)
  end
end
