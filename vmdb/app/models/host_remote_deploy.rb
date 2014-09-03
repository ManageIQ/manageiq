class HostRemoteDeploy < Job
  def load_transitions
    self.state ||= 'initialize'
    {
      :initializing => {'initialize'       => 'waiting_to_start' },
      :start        => {'waiting_to_start' => 'deploy_smartproxy'},
      :abort_job    => {'*'                => 'aborting'         },
      :cancel       => {'*'                => 'canceling'        },
      :finish       => {'*'                => 'finished'         },
      :error        => {'*'                => '*'                }
    }
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

  # Map signals
  alias_method :start,     :call_deploy_smartproxy
  alias_method :abort_job, :process_abort
  alias_method :cancel,    :process_cancel
  alias_method :finish,    :process_finished
  alias_method :error,     :process_error
end
