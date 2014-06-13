require 'workers/queue_worker_base'

class EmsRefreshWorker < QueueWorkerBase
  OPTIONS_PARSER_SETTINGS = WorkerBase::OPTIONS_PARSER_SETTINGS + [
    [:ems_id, 'EMS Instance ID', String],
  ]

  def log_prefix
    @log_prefix ||= "MIQ(#{self.class.name}) EMS [#{@ems.ipaddress}] as [#{@ems.authentication_userid}]"
  end

  def after_initialize
    @ems = ExtManagementSystem.find(@cfg[:ems_id])
    do_exit("Unable to find instance for EMS id [#{@cfg[:ems_id]}].", 1) if @ems.nil?
    do_exit("EMS id [#{@cfg[:ems_id]}] failed authentication check.", 1) unless @ems.authentication_check
  end

  def do_before_work_loop
    $log.info("#{self.log_prefix} Queueing initial refresh for EMS.")
    EmsRefresh.queue_refresh(@ems)
  end

end
