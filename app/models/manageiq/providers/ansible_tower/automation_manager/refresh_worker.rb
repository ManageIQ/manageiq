class ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker < MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    parent
  end

  def self.settings_name
    :ems_refresh_worker_ansible_tower_automation
  end
end
