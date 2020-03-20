class ManageIQ::Providers::StorageManager::Inventory::Persister::SwiftManager < ManageIQ::Providers::StorageManager::Inventory::Persister
  def initialize_inventory_collections
    add_collection(storage, :cloud_object_store_objects)
    add_collection(storage, :cloud_object_store_containers)
  end
end
