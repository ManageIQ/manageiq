module ManageIQ::Providers::AnsibleTower::ConfigurationManager::EventParser
  def self.event_to_hash(event, ems_id)
    {
      :event_type => event.operation,
      :source     => "ANSIBLE_TOWER",
      :message    => event.changes.to_s,
      :timestamp  => event.timestamp,
      :full_data  => event.to_h,
      :ems_id     => ems_id
    }
  end
end
