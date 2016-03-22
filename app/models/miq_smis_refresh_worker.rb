class MiqSmisRefreshWorker < MiqWorker
  require_nested :Runner

  include PerStorageManagerTypeWorkerMixin

  self.required_roles = ["storage_inventory"]
  self.maximum_workers_count = 1

  def friendly_name
    @friendly_name ||= _("Refresh Worker for SMIS")
  end

  def self.storage_manager_class
    MiqSmisAgent
  end
end
