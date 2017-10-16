class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook <
  ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptPayload

  attr_reader :options, :task, :tower

  has_many :jobs, :class_name => 'OrchestrationStack', :foreign_key => :configuration_script_base_id

  def self.run_playbook(task_id)
    task = MiqTask.find(task_id)
    info = task.context_data[:config_info]
    playbook = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook.find(info[:playbook_id])
    playbook.run_playbook(task)
  end

  def run_playbook(task)
    build_instance_vars(task).create_and_launch_job_template
  end

  def raw_name
    "#{@options[:name]}_#{Time.zone.now.to_i}"
  end

  def runner_status(msg)
    @task.update_message(msg)
  end

  def create_and_launch_job_template
    params = build_parameter_list(raw_name, @options[:description] || "#{raw_name} Runner Instance")
    job = nil
    # create_stack would work here if we prebuild the ConfigurationScript record
    #   The code to handle most of that is in ServiceTemplateAnsiblePlaybook.
    #   Only caveat - in the case of the Runner - the plan has been to throw the subsequent
    #   JobTemplate away - so it may not live past a refresh. So not sure if it is worth
    #   building out a real ConfigurationScript object
    #
    #   If we don't build a ConfigurationScript object the below code would have to better
    #   handle exceptions
    @tower.with_provider_connection do |connection|
      template = connection.api.job_templates.create!(params)
      runner_status("Created Job Template")
      job = template.launch
      runner_status("Launched Job Template")
    end
    queue_status(job.id)
  end

  def self.queue_status(job_id, task_id)
    task = MiqTask.find(task_id)
    info = task.context_data[:config_info]
    playbook = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook.find(info[:playbook_id])
    playbook.send(:build_instance_vars, task).queue_status(job_id)
  end

  def reload_job_status(job_id)
    @tower.with_provider_connection do |connection|
      connection.api.jobs.find(job_id)
    end
  end

  def queue_status(job_id)
    job = reload_job_status(job_id)
    if job.status == 'successful'
      @task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, "Playbook launched successfully")
    elsif job.status == 'failed'
      @task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_ERROR, "[#{job_id}] Playbook launch failed")
    else
      @task.update_status(MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, "Playbook still running")
      MiqQueue.put(
        :class_name   => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook",
        :method_name  => 'queue_status',
        :role         => 'embedded_ansible',
        :args         => [job.id, task.id],
        :task_id      => nil,
        :miq_callback => build_queue_callback(task),
        :zone         => @tower.my_zone
      )
    end
  end

  def queue_runner(userid, options)
    tower = manager

    task = MiqTask.create(:name => "Running Ansible Playbook [#{manager_ref}]", :userid => userid, :context_data => options)
    MiqQueue.put(
      :class_name   => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook",
      :method_name  => 'run_playbook',
      :role         => 'embedded_ansible',
      :args         => [task.id],
      :miq_callback => build_queue_callback(task),
      :zone         => tower.my_zone
    )
    task.id
  end

  def self.build_parameter_list(name, description, info)
    playbook = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook.find(info[:playbook_id])
    playbook.build_parameter_list(name, description, info)
  end
  private_class_method :build_parameter_list

  private

  def build_queue_callback(task)
    {
      :class_name  => task.class.name,
      :instance_id => task.id,
      :method_name => :queue_callback_on_exceptions,
      :args        => ['Finished']
    }
  end

  def build_instance_vars(task)
    @task = task
    @options = task.context_data
    @tower = manager
    self
  end

  def build_parameter_list(template_name, description, info = nil)
    options = info.nil? ? @options[:config_info] : info
    tower = @tower || manager
    params = {
      :name                     => template_name,
      :description              => description || '',
      :project                  => configuration_script_source.manager_ref,
      :playbook                 => name,
      :become_enabled           => options[:become_enabled].present?,
      :verbosity                => options[:verbosity].presence || 0,
      :ask_variables_on_launch  => true,
      :ask_limit_on_launch      => true,
      :ask_inventory_on_launch  => true,
      :ask_credential_on_launch => true
    }

    if options[:limit]
      params[:limit] = options[:limit]
    end
    if options[:extra_vars]
      params[:extra_vars] = options[:extra_vars].deep_stringify_keys!.to_json
    end

    hosts = options[:hosts] || options[:extra_vars][:hosts] || tower.provider.default_inventory

    if options[:inventory].nil? && hosts
      params[:inventory] = ServiceAnsiblePlaybook.create_inventory(tower, template_name, hosts).id
      runner_status("Created Inventory with Hosts")
    else
      params[:inventory] = tower.provider.default_inventory
    end

    [:credential, :cloud_credential, :network_credential].each do |credential|
      cred_sym = "#{credential}_id".to_sym
      params[credential] = Authentication.find(options[cred_sym]).manager_ref if options[cred_sym]
    end

    @tower ? params.compact : [tower, params.compact]
  end
end
