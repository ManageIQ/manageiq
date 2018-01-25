class MiqEmsRefreshCoreWorker < MiqWorker
  require_nested :Runner

  include PerEmsWorkerMixin

  self.required_roles = ["ems_inventory"]

  def self.should_start_worker?
    super && !Settings.prototype.ems_vmware.update_driven_refresh
  end

  def self.ems_class
    ManageIQ::Providers::Vmware::InfraManager
  end

  def friendly_name
    @friendly_name ||= begin
      ems = ext_management_system
      ems.nil? ? queue_name.titleize : "Core Refresh Worker for Provider: #{ems.name}"
    end
  end
end
