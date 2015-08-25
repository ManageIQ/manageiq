class ManageIQ::Providers::Foreman::ConfigurationManager::RefreshWorker < MiqEmsRefreshWorker
  require_dependency 'manageiq/providers/foreman/configuration_manager/refresh_worker/runner'

  def self.ems_class
    parent
  end

  def self.settings_name
    :ems_refresh_worker_foreman_configuration
  end
end
