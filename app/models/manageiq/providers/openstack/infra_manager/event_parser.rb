module ManageIQ::Providers::Openstack::InfraManager::EventParser
  def self.event_to_hash(event, ems_id)
    content = message_content(event, ems_id)
    event_type = content["event_type"]
    payload = content["payload"] || {}

    log_header = "ems_id: [#{ems_id}] " unless ems_id.nil?
    _log.debug("#{log_header}event: [#{event_type}]") if $log && $log.debug?

    # attributes that are common to all notifications
    event_hash = {
      :event_type => event_type,
      :source     => "OPENSTACK",
      :message    => payload,
      :timestamp  => content["timestamp"],
      :username   => content["_context_user_name"],
      :full_data  => event,
      :ems_id     => ems_id
    }

    event_hash[:message]                   = payload["message"]           if payload.key? "message"
    event_hash[:host_ems_ref]              = payload["node"]              if payload.key? "node"
    event_hash[:availability_zone_ems_ref] = payload["availability_zone"] if payload.key? "availability_zone"
    event_hash[:chain_id]                  = payload["reservation_id"]    if payload.key? "reservation_id"
    event_hash
  end

  def self.message_content(event, ems_id)
    unless ems_id.nil?
      ems = ExtManagementSystem.find_by_id(ems_id)
      if ems.connection_configuration_by_role("amqp")
        if event[:content].key?("oslo.message")
          return JSON.parse(event[:content]["oslo.message"])
        end
      end
    end
    event[:content]
  end
end
