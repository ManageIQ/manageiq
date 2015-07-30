class ManageIQ::Providers::Openstack::InfraManager::RefreshWorker < ::MiqEmsRefreshWorker
  def self.ems_class
    ManageIQ::Providers::Openstack::InfraManager
  end
end
