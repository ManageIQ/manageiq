module ManageIQ::Providers::Vmware::CloudManager::EventParser
  def self.event_to_hash(event, ems_id)
    event_hash = {
      :event_type => event[:type].sub('com/vmware/vcloud/event/', '').gsub('/', '-'),  # normalized
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
