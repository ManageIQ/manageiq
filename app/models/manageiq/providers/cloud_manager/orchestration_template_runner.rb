class ManageIQ::Providers::CloudManager::OrchestrationTemplateRunner < ::Job
  DEFAULT_EXECUTION_TTL = 100.minutes

  def minimize_indirect
    @minimize_indirect = true if @minimize_indirect.nil?
    @minimize_indirect
  end

  def current_job_timeout(_timeout_adjustment = 1)
    @execution_ttl ||= options[:execution_ttl].present? ? options[:execution_ttl].to_i.minutes : DEFAULT_EXECUTION_TTL
  end

  def start
    time = Time.zone.now
    update(:started_on => time)
    miq_task.update(:started_on => time)
    my_signal(false, :deploy_orchestration_stack, :priority => MiqQueue::HIGH_PRIORITY)
  end

  def reconfigure
    time = Time.zone.now
    update(:started_on => time)
    miq_task.update(:started_on => time)
    my_signal(false, :update_orchestration_stack)
  end

  def deploy_orchestration_stack
    set_status('deploying orchestration stack')

    @orchestration_stack = ManageIQ::Providers::CloudManager::OrchestrationStack.create_stack(
      orchestration_manager, options[:stack_name], orchestration_template, options[:create_options]
    )
    options[:orchestration_stack_id] = @orchestration_stack.id
    self.name = "#{name}, Orchestration Stack ID: #{@orchestration_stack.id}"
    miq_task.update(:name => name)
    save!
    my_signal(false, :poll_stack_status, 10)
  rescue StandardError => err
    _log.error("Error deploying orchestration stack : #{err.class} - #{err.message}")
    my_signal(minimize_indirect, :abort_job, err.message, 'error')
  end

  def update_orchestration_stack
    set_status('updating orchestration stack')

    orchestration_stack.raw_update_stack(orchestration_template, options[:update_options])
    self.name = "#{name}, update Orchestration Stack ID: #{orchestration_stack.id}"
    miq_task.update(:name => name)
    save!
    my_signal(false, :poll_stack_status, 10)
  rescue StandardError => err
    _log.error("Error updating orchestration stack : #{err.class} - #{err.message}")
    my_signal(minimize_indirect, :abort_job, err.message, 'error')
  end

  def poll_stack_status(interval)
    set_status('checking orchestration stack deployment status')

    status, message = orchestration_stack ? orchestration_stack.raw_status.normalized_status : ["check_status_failed", "stack has not been deployed"]
    options.merge!(:orchestration_stack_status => status, :orchestration_stack_message => message)
    save!
    _log.info("Stack deployment status: #{status}, reason: #{message}")

    case status.downcase
    when 'create_complete', 'update_complete'
      my_signal(minimize_indirect, :post_stack_run, "Orchestration stack [#{orchestration_stack.name}] #{status}", 'ok')
    when 'rollback_complete', 'delete_complete', /failed$/, /canceled$/
      _log.error("Orchestration stack deployment error: #{message}. Please examine stack resources for more details")
      my_signal(minimize_indirect, :abort_job, "Orchestration stack deployment error: #{message}", 'error')
    else
      interval = 60 if interval > 60
      my_signal(false, :poll_stack_status, interval * 2, :deliver_on => Time.now.utc + interval)
    end
  rescue MiqException::MiqOrchestrationStackNotExistError, MiqException::MiqOrchestrationStatusError => err
    # naming convention requires status to end with "failed"
    options.merge!(:orchestration_stack_status => 'check_status_failed', :orchestration_stack_message => err.message)
    save!
    _log.error("Error polling orchestration stack status : #{err.class} - #{err.message}")
    my_signal(minimize_indirect, :abort_job, err.message, 'error')
  end

  def post_stack_run(message, status)
    my_signal(true, :finish, message, status)
  end

  def set_status(message, status = "ok")
    _log.info(message)
    super
  end

  def my_signal(no_queue, action, *args, deliver_on: nil, priority: MiqQueue::NORMAL_PRIORITY)
    if no_queue
      signal(action, *args)
    else
      queue_signal(action, *args, :deliver_on => deliver_on, :priority => priority)
    end
  end

  def queue_signal(*args, deliver_on: nil, priority: MiqQueue::NORMAL_PRIORITY)
    super(*args, :role => 'ems_operations', :deliver_on => deliver_on, :priority => priority)
  end

  def orchestration_stack
    OrchestrationStack.find_by(:id => options[:orchestration_stack_id])
  end

  def orchestration_stack_status
    options[:orchestration_stack_status]
  end

  def orchestration_stack_message
    options[:orchestration_stack_message]
  end

  alias initializing dispatch_start
  alias finish       process_finished
  alias abort_job    process_abort
  alias cancel       process_cancel
  alias error        process_error

  private

  attr_writer :minimize_indirect

  def load_transitions
    self.state ||= 'initialize'

    {
      :initializing               => {'initialize'       => 'waiting_to_start'},
      :start                      => {'waiting_to_start' => 'running'},
      :reconfigure                => {'waiting_to_start' => 'updating'},
      :deploy_orchestration_stack => {'running'          => 'stack_job'},
      :update_orchestration_stack => {'updating'         => 'stack_job'},
      :poll_stack_status          => {'stack_job'        => 'stack_job'},
      :post_stack_run             => {'stack_job'        => 'stack_done'},
      :finish                     => {'*'                => 'finished'},
      :abort_job                  => {'*'                => 'aborting'},
      :cancel                     => {'*'                => 'canceling'},
      :error                      => {'*'                => '*'}
    }
  end

  def orchestration_manager
    ExtManagementSystem.find_by(:id => options[:orchestration_manager_id])
  end

  def orchestration_template
    OrchestrationTemplate.find_by(:id => options[:orchestration_template_id])
  end
end
