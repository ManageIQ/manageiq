class ManageIQ::Providers::Foreman::ConfigurationManager::RefreshWorker < MiqEmsRefreshWorker
  def self.ems_class
    parent
  end

  def self.settings_name
    :ems_refresh_worker_foreman_configuration
  end
end
