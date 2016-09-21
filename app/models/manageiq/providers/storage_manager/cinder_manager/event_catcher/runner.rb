class ManageIQ::Providers::StorageManager::CinderManager::EventCatcher::Runner <
  ManageIQ::Providers::BaseManager::EventCatcher::Runner
  def add_cinder_queue(event_hash)
    EmsEvent.add_queue('add_cinder', @cfg[:ems_id], event_hash)
  end
end
