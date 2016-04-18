class ManageIQ::Providers::BaseManager::EventCatcher::Parser

  attr_reader :filtered_events

  def initialize(filtered_events = [])
    @filtered_events = filtered_events
  end

  def event_to_hash(event)
    raise NotImplementedError, "must be implemented in subclass"
  end

  def process_event?(event)
    false
  end
end
