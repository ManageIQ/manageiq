class ManageIQ::Providers::Vmware::NetworkManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Vmware::NetworkManager
  end

  def self.settings_name
    :ems_refresh_worker_vmware_cloud
  end
end
