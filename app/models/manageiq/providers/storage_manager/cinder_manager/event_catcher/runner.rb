class ManageIQ::Providers::StorageManager::CinderManager::EventCatcher::Runner <
  ManageIQ::Providers::BaseManager::EventCatcher::Runner
  def add_cinder_queue(event_hash)
    event_hash = ManageIQ::Providers::StorageManager::CinderManager::EventParser.event_to_hash(event_hash, @cfg[:ems_id])
    EmsEvent.add_queue('add', @cfg[:ems_id], event_hash)
  end
end
