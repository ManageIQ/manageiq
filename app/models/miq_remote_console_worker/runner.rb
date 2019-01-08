class MiqRemoteConsoleWorker::Runner < MiqWorker::Runner
  include MiqWebServerRunnerMixin

  def heartbeat(*args)
    ret = super
    check_internal_thread
    ret
  end

  def check_internal_thread
    unless worker.rails_application.healthy?
      do_exit("MiqRemoteConsoleWorker internal thread crashed, exiting!", 1)
    end
  end
end
