class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::RefreshWorker < MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    parent
  end

  def self.settings_name
    :ems_refresh_worker_embedded_ansible_automation
  end
end
