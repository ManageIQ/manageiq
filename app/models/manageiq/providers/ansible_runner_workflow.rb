class ManageIQ::Providers::AnsibleRunnerWorkflow < Job
  def self.create_job(env_vars, extra_vars, role_or_playbook_options,
                      hosts = ["localhost"], credentials = [],
                      timeout: 1.hour, poll_interval: 1.second, verbosity: 0, become_enabled: false)
    super(name, role_or_playbook_options.merge(
      :become_enabled => become_enabled,
      :credentials    => credentials,
      :env_vars       => env_vars,
      :extra_vars     => extra_vars,
      :hosts          => hosts,
      :timeout        => timeout,
      :poll_interval  => poll_interval,
      :verbosity      => verbosity
    ))
  end

  def current_job_timeout(_timeout_adjustment = 1)
    options[:timeout] || super
  end

  def execution_type
    raise NotImplementedError, "must be implemented in a subclass"
  end

  def start
    queue_signal(:pre_execute)
  end

  def pre_execute
    verify_options
    prepare_repository
    queue_signal(:execute)
  end

  def launch_runner
    raise NotImplementedError, "must be implemented in a subclass"
  end

  def execute
    response = launch_runner

    if response.nil?
      queue_signal(:abort, "Failed to run ansible #{execution_type}", "error")
    else
      context[:ansible_runner_response] = response.dump

      started_on = Time.now.utc
      update!(:context => context, :started_on => started_on)
      miq_task.update!(:started_on => started_on)

      queue_signal(:poll_runner)
    end
  end

  def poll_runner
    response = Ansible::Runner::ResponseAsync.load(context[:ansible_runner_response])
    if response.running?
      if started_on + options[:timeout] < Time.now.utc
        response.stop

        queue_signal(:abort, "ansible #{execution_type} has been running longer than timeout", "error")
      else
        queue_signal(:poll_runner, :deliver_on => deliver_on)
      end
    else
      result = response.response

      context[:ansible_runner_return_code] = result.return_code
      context[:ansible_runner_stdout]      = result.parsed_stdout

      if result.return_code != 0
        set_status("ansible #{execution_type} failed", "error")
        _log.warn("ansible #{execution_type} failed:\n#{result.parsed_stdout.join("\n")}")
      else
        set_status("ansible #{execution_type} completed with no errors", "ok")
      end
      queue_signal(:post_execute)
    end
  end

  def post_execute
    cleanup_git_repository
    queue_signal(:finish, message, status)
  end

  alias initializing dispatch_start
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
      :server_guid => MiqServer.my_server.guid
    )
  end

  def deliver_on
    Time.now.utc + options[:poll_interval]
  end

  def load_transitions
    self.state ||= 'initialize'

    {
      :initializing => {'initialize'       => 'waiting_to_start'},
      :start        => {'waiting_to_start' => 'pre_execute'},
      :pre_execute  => {'pre_execute'      => 'execute'},
      :execute      => {'execute'          => 'running'},
      :poll_runner  => {'running'          => 'running'},
      :post_execute => {'running'          => 'post_execute'},
      :finish       => {'*'                => 'finished'},
      :abort_job    => {'*'                => 'aborting'},
      :cancel       => {'*'                => 'canceling'},
      :error        => {'*'                => '*'}
    }
  end

  private

  def verify_options
    raise NotImplementedError, "must be implemented in a subclass"
  end

  def prepare_repository
    return unless options[:configuration_script_source_id]

    checkout_git_repository
    adjust_options_for_git_checkout_tempdir!
  end

  def adjust_options_for_git_checkout_tempdir!
    raise NotImplementedError, "must be implemented in a subclass"
  end

  def checkout_git_repository
    css = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource.find(options[:configuration_script_source_id])
    options[:git_checkout_tempdir] = Dir.mktmpdir("ansible-runner-git")
    save!
    _log.info("Checking out git repository to #{options[:git_checkout_tempdir].inspect}...")
    css.checkout_git_repository(options[:git_checkout_tempdir])
  end

  def cleanup_git_repository
    return unless options[:git_checkout_tempdir]

    _log.info("Cleaning up git repository checkout at #{options[:git_checkout_tempdir].inspect}...")
    FileUtils.rm_rf(options[:git_checkout_tempdir])
  end
end
