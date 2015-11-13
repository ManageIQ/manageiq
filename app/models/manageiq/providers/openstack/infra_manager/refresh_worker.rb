class ManageIQ::Providers::Openstack::InfraManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Openstack::InfraManager
  end

  def self.settings_name
    :ems_refresh_worker_openstack_infra
  end
end
