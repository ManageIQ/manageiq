class ManageIQ::Providers::AnsibleTower::ConfigurationManager::RefreshWorker < MiqEmsRefreshWorker
  require_nested :Collector
  require_nested :Parser
  require_nested :Runner

  def self.ems_class
    parent
  end

  def self.settings_name
    :ems_refresh_worker_ansible_tower_configuration
  end
end
