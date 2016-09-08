class ManageIQ::Providers::StorageManager::CinderStorageManager::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner

  def add_cinder_storage_queue(event_hash)
    EmsEvent.add_queue('add_cinder_storage', @cfg[:ems_id], event_hash)
  end
end
