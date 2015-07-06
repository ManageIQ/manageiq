class MiqVmdbStorageBridgeWorker < MiqQueueWorkerBase
  self.required_roles       = ["vmdb_storage_bridge"]
  self.default_queue_name   = "vmdb_storage_bridge"
  self.workers              = 1

  def friendly_name
    @friendly_name ||= "Storage/Virtual Associations Worker"
  end

end
