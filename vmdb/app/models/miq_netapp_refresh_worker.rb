class MiqNetappRefreshWorker < MiqQueueWorkerBase
  include PerStorageManagerTypeWorkerMixin

  self.required_roles     = ["storage_inventory"]
  self.default_queue_name = "netapp_refresh"
  self.maximum_workers_count = 1

  def friendly_name
    @friendly_name ||= "Refresh Worker for NetApp Storage"
  end

  def self.storage_manager_class
    NetappRemoteService
  end
end
