class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::PlaybookRunner < ::Job
  # options are job table columns, including options column which is the playbook context info
  def self.create_job(options)
    super(name, options.with_indifferent_access)
  end

  def minimize_indirect
    @minimize_indirect = true if @minimize_indirect.nil?
    @minimize_indirect
  end

  def start
    time = Time.zone.now
    update_attributes(:started_on => time)
    miq_task.update_attributes(:started_on => time)
    if options[:inventory]
      my_signal(false, :create_job_template)
    else
      my_signal(false, :create_inventory)
    end
  end

  def create_inventory
    set_status('creating inventory')
    tower = playbook.manager
    hosts = options[:hosts] || options.fetch_path(:extra_vars, :hosts)
    options[:inventory] =
      if hosts == 'localhost' || hosts.nil?
        tower.provider.default_inventory
      else
        inventory_name = "#{playbook.name}_#{Time.zone.now.to_i}"
        ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Inventory.raw_create_inventory(tower, inventory_name, hosts).id
      end
    save!
    my_signal(minimize_indirect, :create_job_template)
  rescue => err
    _log.log_backtrace(err)
    my_signal(minimize_indirect, :post_ansible_run, err.message, 'error')
  end

  def create_job_template
    set_status('creating job template')
    raw_job_template = playbook.raw_create_job_template(options)
    options[:job_template_ref] = raw_job_template.id
    save!

    my_signal(minimize_indirect, :launch_ansible_tower_job)
  rescue => err
    _log.log_backtrace(err)
    my_signal(minimize_indirect, :post_ansible_run, err.message, 'error')
  end

  def launch_ansible_tower_job
    set_status('launching tower job')
    job_template = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript.new(
      :manager     => playbook.manager,
      :manager_ref => options[:job_template_ref],
      :variables   => {}
    )
    launch_options = options.slice(:extra_vars, :limit)
    tower_job = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job.create_job(job_template, launch_options)
    options[:tower_job_id] = tower_job.id
    self.name = "#{name}, Job ID: #{tower_job.id}"
    miq_task.update_attributes(:name => name)
    save!

    my_signal(false, :poll_ansible_tower_job_status, 10)
  rescue => err
    _log.log_backtrace(err)
    my_signal(minimize_indirect, :post_ansible_run, err.message, 'error')
  end

  def poll_ansible_tower_job_status(interval)
    set_status('waiting for tower job to complete')

    tower_job_status = tower_job.raw_status
    if tower_job_status.completed?
      tower_job.refresh_ems
      if tower_job_status.succeeded?
        my_signal(minimize_indirect, :post_ansible_run, 'Playbook ran successfully', 'ok')
      else
        my_signal(minimize_indirect, :post_ansible_run, 'Ansible engine returned an error for the job', 'error')
      end
    else
      interval = 60 if interval > 60
      my_signal(false, :poll_ansible_tower_job_status, interval * 2, :deliver_on => Time.now.utc + interval)
    end
  rescue => err
    _log.log_backtrace(err)
    my_signal(minimize_indirect, :post_ansible_run, err.message, 'error')
  end

  def post_ansible_run(*args)
    # delete inventory, job_template, job?
    my_signal(true, :finish, *args)
  end

  alias_method :initializing, :dispatch_start
  alias_method :finish,       :process_finished
  alias_method :abort_job,    :process_abort
  alias_method :cancel,       :process_cancel
  alias_method :error,        :process_error

  private

  attr_writer :minimize_indirect

  def load_transitions
    self.state ||= 'initialize'

    {
      :initializing                  => {'initialize'       => 'waiting_to_start'},
      :start                         => {'waiting_to_start' => 'running'},
      :create_inventory              => {'running'          => 'inventory'},
      :create_job_template           => {'inventory'        => 'job_template', 'running' => 'job_template'},
      :launch_ansible_tower_job      => {'job_template'     => 'ansible_job'},
      :poll_ansible_tower_job_status => {'ansible_job'      => 'ansible_job'},
      :post_ansible_run              => {'inventory'        => 'ansible_done', 'job_template' => 'ansible_done', 'ansible_job' => 'ansible_done'},
      :finish                        => {'*'                => 'finished'},
      :abort_job                     => {'*'                => 'aborting'},
      :cancel                        => {'*'                => 'canceling'},
      :error                         => {'*'                => '*'}
    }
  end

  def my_signal(no_queue, action, *args, deliver_on: nil)
    if no_queue
      signal(action, *args)
    else
      queue_signal(action, *args, :deliver_on => deliver_on)
    end
  end

  def queue_signal(*args, deliver_on: nil)
    priority = options[:priority] || MiqQueue::NORMAL_PRIORITY

    MiqQueue.put(
      :class_name  => self.class.name,
      :method_name => "signal",
      :instance_id => id,
      :priority    => priority,
      :role        => 'embedded_ansible',
      :args        => args,
      :deliver_on  => deliver_on
    )
  end

  def playbook
    ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook.find(options[:playbook_id])
  end

  def tower_job
    ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job.find(options[:tower_job_id])
  end
end
