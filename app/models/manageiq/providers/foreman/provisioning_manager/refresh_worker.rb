class ManageIQ::Providers::Foreman::ProvisioningManager::RefreshWorker < MiqEmsRefreshWorker
  def self.ems_class
    parent
  end

  def self.settings_name
    :ems_refresh_worker_foreman_provisioning
  end
end
