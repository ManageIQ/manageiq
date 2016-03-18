module ManageIQ::Providers::Openstack::NetworkManager::EventParser
  def self.event_to_hash(event, ems_id)
    log_header = "ems_id: [#{ems_id}] " unless ems_id.nil?

    _log.debug("#{log_header}event: [#{event[:content]["event_type"]}]")

    # attributes that are common to all notifications
    event_hash = {
      :event_type => event[:content]["event_type"],
      :source     => "OPENSTACK",
      :message    => event[:payload],
      :timestamp  => event[:content]["timestamp"],
      :username   => event[:content]["_context_user_name"],
      :full_data  => event,
      :ems_id     => ems_id
    }

    payload = event[:content]["payload"]
    event_hash[:vm_ems_ref] = payload["instance_id"]                      if payload.key? "instance_id"
    event_hash[:host_ems_ref] = payload["host"]                           if payload.key? "host"
    event_hash[:availability_zone_ems_ref] = payload["availability_zone"] if payload.key? "availability_zone"
    event_hash[:chain_id] = payload["reservation_id"]                     if payload.key? "reservation_id"
    event_hash
  end
end
