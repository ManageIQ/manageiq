class ManageIQ::Providers::StorageManager::SwiftManager::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner
  include ManageIQ::Providers::StorageManager::EventCatcherMixin

  def add_storage_queue(event_hash)
    EmsEvent.add_queue('add_swift', @cfg[:ems_id], event_hash)
  end
end
