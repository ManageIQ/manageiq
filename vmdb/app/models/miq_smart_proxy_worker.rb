class MiqSmartProxyWorker < MiqQueueWorkerBase
  self.required_roles       = ["smartproxy"]
  self.default_queue_name   = "smartproxy"

end
