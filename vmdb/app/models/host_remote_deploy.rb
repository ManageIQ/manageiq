class HostRemoteDeploy < Job
  state_machine :state, :initial => :initialize do
    event :initializing do
      transition :initialize => :waiting_to_start
    end

    event :start do
      transition :waiting_to_start => :deploy_smartproxy
    end
    after_transition :on => :start, :waiting_to_start => :deploy_smartproxy, :do => :call_deploy_smartproxy

    event :abort_job do
      transition all => :aborting
    end

    event :cancel do
      transition all => :canceling
    end

    event :finish do
      transition all => :finished
    end

    event :error do
      transition all => same
    end
    # On the Error event, call the error method
    after_transition :on => :error,     :do => :process_error

    # On Entry to the State
    after_transition all => :aborting,  :do => :process_abort
    after_transition all => :canceling, :do => :process_cancel
    after_transition all => :finished,  :do => :process_finished
  end

  def call_deploy_smartproxy
    $log.info "action-call_deploy_smartproxy: Enter"
    miq_proxy = MiqProxy.find(self.agent_id)
    begin
      miq_proxy.deploy_agent_version_from_job(self.options[:deploy_options]) {|msg| self.set_status(msg)}
      signal(:finish, "Process completed successfully", "ok")
    rescue MiqException::MiqDeploymentError
      $log.error "HOST DEPLOY JOB ERROR: [#{$!}]"
      signal(:abort, $!.to_s, "error")
    rescue
      $log.error "HOST DEPLOY JOB ERROR: [#{$!}]"
      $log.error "HOST DEPLOY JOB ERROR: [#{$!.backtrace.join("\n")}]"
      signal(:abort, $!.to_s, "error")
    end
  end
end
