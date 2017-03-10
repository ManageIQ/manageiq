module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Refresher
  def collect_inventory_for_targets(ems, targets)
    ems.with_provider_connection do |connection|
      # FIXME: this should really be somewhere else
      ems.api_version = connection.api.version
      ems.save
    end
    super
  end
end
