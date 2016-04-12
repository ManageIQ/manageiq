module ManageIQ::Providers::Azure::CloudManager::EventParser
  extend ManageIQ::Providers::Azure::EventCatcherMixin

  def self.event_to_hash(event, ems_id)
    log_header = "ems_id: [#{ems_id}] " unless ems_id.nil?
    event_type = parse_event_type(event)
    _log.debug("#{log_header}event: [#{event_type}]")

    {
      :source     => "AZURE",
      :timestamp  => event["eventTimestamp"],
      :message    => event["description"].blank? ? nil : event["description"],
      :ems_id     => ems_id,
      :event_type => event_type,
      :full_data  => event
    }
  end
end
