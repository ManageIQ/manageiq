class ManageIQ::Providers::Openstack::CloudManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_dependency 'manageiq/providers/openstack/cloud_manager/refresh_worker/runner'

  def self.ems_class
    ManageIQ::Providers::Openstack::CloudManager
  end
end
