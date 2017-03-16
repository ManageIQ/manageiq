module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::EventParser
  def event_to_hash(event, ems_id)
    {
      :event_type => "#{event['object1']}_#{event['operation']}",
      :source     => "#{self.source}",
      :timestamp  => event['timestamp'],
      :full_data  => event,
      :ems_id     => ems_id
    }
  end
end
