module ManageIQ::Providers::Vmware::CloudManager::EventParser
  def self.event_to_hash(event, ems_id)
    log_header = "ems_id: [#{ems_id}] " unless ems_id.nil?
    _log.debug("#{log_header}event: [#{event[:event_type]}]")

    event_hash = {
      # TODO: implement rel4 policies for vmware cloud
      :event_type => "go-to-missing",
      # :event_type => event[:event_type],
      :source     => "VMWARE-VCLOUD",
      :message    => event.to_hash,
      :timestamp  => event[:timestamp],
      :vm_ems_ref => event[:instance_id],
      :full_data  => event,
      :ems_id     => ems_id,
    }

    event_hash
  end
end
