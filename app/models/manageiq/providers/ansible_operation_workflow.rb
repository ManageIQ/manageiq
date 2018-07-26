class ManageIQ::Providers::AnsibleOperationWorkflow < Job
  def self.create_job(env_vars, extra_vars, playbook_path, timeout: 1.hour, poll_interval: 1.minute)
    options = {
      :env_vars      => env_vars,
      :extra_vars    => extra_vars,
      :playbook_path => playbook_path,
      :timeout       => timeout,
      :poll_interval => poll_interval,
    }

    super(name, options)
  end

  def pre_playbook
    # A step before running the playbook for any optional setup tasks
    queue_signal(:run_playbook)
  end

  def run_playbook
    env_vars, extra_vars, playbook_path = options.values_at(:env_vars, :extra_vars, :playbook_path)

    uuid = Ansible::Runner.run_async(env_vars, extra_vars, playbook_path)
    if uuid.nil?
      queue_signal(:error)
    else
      context[:ansible_runner_uuid] = uuid
      update_attributes!(:context => context)

      queue_signal(:poll_runner)
    end
  end

  def poll_runner
    if Ansible::Runner.running?(context[:ansible_runner_uuid])
      queue_signal(:poll_runner, :deliver_on => deliver_on)
    else
      queue_signal(:post_playbook)
    end
  end

  def post_playbook
    # A step after running the playbook for any optional cleanup tasks
    queue_signal(:finish)
  end

  alias initializing dispatch_start
  alias start        pre_playbook
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
      :start         => {'waiting_to_start' => 'pre_playbook'},
      :run_playbook  => {'pre_playbook'     => 'running'},
      :poll_runner   => {'running'          => 'running'},
      :post_playbook => {'running'          => 'post_playbook'},
      :finish        => {'*'                => 'finished'},
      :abort_job     => {'*'                => 'aborting'},
      :cancel        => {'*'                => 'canceling'},
      :error         => {'*'                => '*'}
    }
  end
end
