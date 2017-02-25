module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::EventParser
  def event_to_hash(event, ems_id)
    {
      :event_type => "#{self.event_type}_#{event.operation}",
      :source     => "#{self.source}",
      :message    => event.changes.to_s,
      :timestamp  => event.timestamp,
      :full_data  => event.to_h,
      :ems_id     => ems_id
    }
  end
end
