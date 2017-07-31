class MiqEmsRefreshCoreWorker < MiqWorker
  require_nested :Runner

  include PerEmsWorkerMixin

  self.required_roles = ["ems_inventory"]

  def self.has_required_role?
    return false if Settings.prototype.try(:ems_vmware).try(:update_driven_refresh)
    super
  end

  def self.ems_class
    ManageIQ::Providers::Vmware::InfraManager
  end

  def friendly_name
    @friendly_name ||= begin
      ems = ext_management_system
      ems.nil? ? queue_name.titleize : "Core Refresh Worker for #{ui_lookup(:table => "ext_management_systems")}: #{ems.name}"
    end
  end
end
