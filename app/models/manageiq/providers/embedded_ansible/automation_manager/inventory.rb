class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Inventory < ManageIQ::Providers::EmbeddedAutomationManager::InventoryRootGroup
  def self.raw_create_inventory(tower, inventory_name, hosts)
    miq_org = tower.provider.default_organization
    tower.with_provider_connection do |connection|
      connection.api.inventories.create!(:name => inventory_name, :organization => miq_org).tap do |inventory|
        hosts.split(',').each do |host|
          connection.api.hosts.create!(:name => host, :inventory => inventory.id)
        end
      end
    end
  end
end
