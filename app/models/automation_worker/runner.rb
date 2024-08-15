class AutomationWorker::Runner < MiqQueueWorkerBase::Runner
  def do_before_work_loop
    super
    @automation_runners = Vmdb::Plugins.automation_runner_classes.map(&:runner)
  end

  def before_exit(*)
    super
    @automation_runners.each(&:stop)
  end
end
