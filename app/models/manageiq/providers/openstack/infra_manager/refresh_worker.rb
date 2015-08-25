class ManageIQ::Providers::Openstack::InfraManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_dependency 'manageiq/providers/openstack/infra_manager/refresh_worker/runner'

  def self.ems_class
    ManageIQ::Providers::Openstack::InfraManager
  end
end
