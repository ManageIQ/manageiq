class MiqEmsInventoryPersister < MiqQueueWorkerBase
  require_nested :Runner

  self.required_roles = ["ems_inventory"]
  self.default_queue_name = "inventory"
end
