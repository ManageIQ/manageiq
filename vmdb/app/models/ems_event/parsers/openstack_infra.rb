module EmsEvent::Parsers::OpenstackInfra
  def self.event_to_hash(event, ems_id)
    log_header = "MIQ(#{self.name}.event_to_hash)"
    log_header << " ems_id: [#{ems_id}]" unless ems_id.nil?

    $log.debug("#{log_header} event: [#{event[:content]["event_type"]}]") if $log && $log.debug?

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
    event_hash[:host_ems_ref] = Host.where('ems_ref_obj LIKE ?', "%#{payload['instance_id']}%").first.try(:ems_ref) if payload.has_key? "instance_id"
    event_hash[:availability_zone_ems_ref] = payload["availability_zone"] if payload.has_key? "availability_zone"
    event_hash[:chain_id] = payload["reservation_id"]                     if payload.has_key? "reservation_id"
    event_hash
  end
end
