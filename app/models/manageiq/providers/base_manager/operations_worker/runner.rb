class ManageIQ::Providers::BaseManager::OperationsWorker::Runner < ::MiqQueueWorkerBase::Runner
  OPTIONS_PARSER_SETTINGS = ::MiqWorker::Runner::OPTIONS_PARSER_SETTINGS + [
    [:ems_id, 'EMS Instance ID', String],
  ]

  def worker_roles
    %w[ems_operations"]
  end

  attr_reader :ems

  def after_initialize
    @ems = ExtManagementSystem.find(@cfg[:ems_id])
    do_exit("Unable to find instance for EMS id [#{@cfg[:ems_id]}].", 1) if ems.nil?
    do_exit("EMS id [#{ems.id}] failed authentication check.", 1) unless ems.authentication_check.first
  end
end
