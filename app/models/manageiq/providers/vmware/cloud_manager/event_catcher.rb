class ManageIQ::Providers::Vmware::CloudManager::EventCatcher < ::MiqEventCatcher
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Vmware::CloudManager
  end

  def self.settings_name
    :event_catcher_vmware_cloud
  end
end
