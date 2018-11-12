class ManageIQ::Providers::AnsibleRunnerWorkflow < Job
  def self.create_job(env_vars, extra_vars, role_or_playbook_options, timeout: 1.hour, poll_interval: 1.second)
    super(name, job_options(env_vars, extra_vars, role_or_playbook_options, timeout, poll_interval))
  end

  def current_job_timeout(_timeout_adjustment = 1)
    options[:timeout] || super
  end

  def job_options(options)
    raise(NotImplementedError, 'abstract')
  end

  def poll_runner
    response = Ansible::Runner::ResponseAsync.load(context[:ansible_runner_response])
    if response.running?
      if started_on + options[:timeout] < Time.now.utc
        response.stop

        queue_signal(:abort, "Playbook has been running longer than timeout", "error")
      else
        queue_signal(:poll_runner, :deliver_on => deliver_on)
      end
    else
      result = response.response

      context[:ansible_runner_return_code] = result.return_code
      context[:ansible_runner_stdout]      = result.parsed_stdout

      if result.return_code != 0
        set_status("Playbook failed", "error")
        _log.warn("Playbook failed:\n#{result.parsed_stdout.join("\n")}")
      else
        set_status("Playbook completed with no errors", "ok")
      end
      queue_signal(:post_playbook)
    end
  end

  def post_playbook
    # A step after running the playbook for any optional cleanup tasks
    queue_signal(:finish, message, status)
  end

  def fail_unimplamented
    raise(NotImplementedError, "this is an abstract class, use a subclass that implaments a 'start' method")
  end

  alias initializing dispatch_start
  alias start        fail_unimplamented
  alias finish       process_finished
  alias abort_job    process_abort
  alias cancel       process_cancel
  alias error        process_error

  protected

  def queue_signal(*args, deliver_on: nil)
    role     = options[:role] || "ems_operations"
    priority = options[:priority] || MiqQueue::NORMAL_PRIORITY

    MiqQueue.put(
      :class_name  => self.class.name,
      :method_name => "signal",
      :instance_id => id,
      :priority    => priority,
      :role        => role,
      :zone        => zone,
      :task_id     => guid,
      :args        => args,
      :deliver_on  => deliver_on,
      :server_guid => MiqServer.my_server.guid,
    )
  end

  def deliver_on
    Time.now.utc + options[:poll_interval]
  end

  def load_transitions
    self.state ||= 'initialize'

    {
      :initializing  => {'initialize'       => 'waiting_to_start'},
      :poll_runner   => {'running'          => 'running'},
      :post_playbook => {'running'          => 'post_playbook'},
      :finish        => {'*'                => 'finished'},
      :abort_job     => {'*'                => 'aborting'},
      :cancel        => {'*'                => 'canceling'},
      :error         => {'*'                => '*'}
    }
  end
end
