class AmazonAgentManagerWorker < MiqQueueWorkerBase
  require_nested :Runner
  
  self.required_roles = ['smartproxy']

  # Don't allow multiple ansible monitor workers to run at once
  self.include_stopping_workers_on_synchronize = true


  def self.find_or_create_agent(ost)
    vm = VmOrTemplate.find(ost.target_id)
    guid = vm.ext_management_system.guid

    _log.info("Finding Amazon SSA agent on EMS: [#{guid}]")
    AmazonAgentManagerWorker::Runner.find_or_create_agent(guid)
  end
end
