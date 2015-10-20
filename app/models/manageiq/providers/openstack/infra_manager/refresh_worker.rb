class ManageIQ::Providers::Openstack::InfraManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Openstack::InfraManager
  end
end
