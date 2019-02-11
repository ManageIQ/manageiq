class ManageIQ::Providers::EmbeddedAnsible::Inventory::Persister::TargetCollection < ManageIQ::Providers::EmbeddedAnsible::Inventory::Persister
  include ManageIQ::Providers::AnsibleTower::Inventory::Persister::Definitions::AutomationCollections

  def targeted?
    true
  end

  def strategy
    :local_db_find_missing_references
  end

  def initialize_inventory_collections
    initialize_automation_inventory_collections
  end
end
