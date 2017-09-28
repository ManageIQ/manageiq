class AmazonAgentManagerWorker < MiqWorker
  require_nested :Runner
  self.required_roles = ['smartproxy']

  # Don't allow multiple workers to run at once
  self.include_stopping_workers_on_synchronize = true
end
