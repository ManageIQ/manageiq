class ManageIQ::Providers::Openstack::CloudManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Openstack::CloudManager
  end
end
