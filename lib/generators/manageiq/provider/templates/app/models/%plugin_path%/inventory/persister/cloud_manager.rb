class <%= class_name %>::Inventory::Persister::CloudManager < <%= class_name %>::Inventory::Persister
  include <%= class_name %>::Inventory::Persister::Definitions::CloudCollections

  def initialize_inventory_collections
    initialize_cloud_inventory_collections
  end
end
