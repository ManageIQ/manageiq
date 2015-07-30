class ManageIQ::Providers::Openstack::CloudManager::RefreshWorker < ::MiqEmsRefreshWorker
  def self.ems_class
    ManageIQ::Providers::Openstack::CloudManager
  end
end
