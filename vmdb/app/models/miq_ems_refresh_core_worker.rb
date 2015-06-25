class MiqEmsRefreshCoreWorker < MiqWorker
  include PerEmsWorkerMixin

  self.required_roles = ["ems_inventory"]

  def self.ems_class
    ManageIQ::Providers::Vmware::InfraManager
  end

  def friendly_name
    @friendly_name ||= begin
      ems = self.ext_management_system
      ems.nil? ? self.queue_name.titleize : "Core Refresh Worker for #{ui_lookup(:table => "ext_management_systems")}: #{ems.name}"
    end
  end
end
