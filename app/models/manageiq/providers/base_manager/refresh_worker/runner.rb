class ManageIQ::Providers::BaseManager::RefreshWorker::Runner < ::MiqQueueWorkerBase::Runner
  def after_initialize
    @emss = ExtManagementSystem.find([@cfg[:ems_id]])
    @emss.each do |ems|
      do_exit("Unable to find instance for EMS id [#{@cfg[:ems_id]}].", 1) if ems.nil?
      do_exit("EMS id [#{ems.id}] failed authentication check.", 1) unless ems.authentication_check.first
    end
  end

  def do_before_work_loop
    @emss.each do |ems|
      log_prefix = "EMS [#{ems.hostname}] as [#{ems.authentication_userid}]"
      _log.info("#{log_prefix} Queueing initial refresh for EMS #{ems.id}.")
      EmsRefresh.queue_refresh(ems)
    end
  end
end
