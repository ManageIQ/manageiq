class <%= class_name %>::Inventory::Persister < ManageIQ::Providers::Inventory::Persister
  require_nested :<%= manager_type %>

  def initialize_inventory_collections
    add_cloud_collection(:vms)
  end
end
