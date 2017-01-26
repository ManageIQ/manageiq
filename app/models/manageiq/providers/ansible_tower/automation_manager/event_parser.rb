module ManageIQ::Providers::AnsibleTower::AutomationManager::EventParser
  def self.event_to_hash(event, ems_id)
    {
      :event_type => "ansible_tower_#{event.operation}",
      :source     => "ANSIBLE_TOWER",
      :message    => event.changes.to_s,
      :timestamp  => event.timestamp,
      :full_data  => event.to_h,
      :ems_id     => ems_id
    }
  end
end
