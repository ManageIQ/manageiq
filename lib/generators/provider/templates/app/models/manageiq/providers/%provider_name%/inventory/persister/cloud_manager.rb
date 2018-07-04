class ManageIQ::Providers::<%= class_name %>::Inventory::Persister::CloudManager < ManageIQ::Providers::<%= class_name %>::Inventory::Persister
  include ManageIQ::Providers::<%= class_name %>::Inventory::Persister::Definitions::CloudCollections

  def initialize_inventory_collections
    initialize_cloud_inventory_collections
  end
end
