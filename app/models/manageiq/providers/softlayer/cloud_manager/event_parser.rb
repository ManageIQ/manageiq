module ManageIQ::Providers::SoftLayer::CloudManager::EventParser
  def self.event_to_hash(event, ems_id)
    log_header = "ems_id: [#{ems_id}] " unless ems_id.nil?

    _log.debug { "#{log_header}event: [#{event["eventType"]}]" }

    event_hash = {
      :event_type => event["eventType"],
      :source     => "SOFTLAYER",
      :message    => event["configurationItemDiff"],
      :timestamp  => event["notificationCreationTime"],
      :full_data  => event,
      :ems_id     => ems_id
    }

    event_hash
  end
end
