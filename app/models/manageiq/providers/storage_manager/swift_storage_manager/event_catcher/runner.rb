class ManageIQ::Providers::StorageManager::SwiftStorageManager::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner

  def add_openstack_queue(event_hash)
    EmsEvent.add_queue('add_swift_storage', @cfg[:ems_id], event_hash)
  end
end
