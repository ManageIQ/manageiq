class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job < ManageIQ::Providers::EmbeddedAutomationManager::OrchestrationStack
  include CiFeatureMixin

  require_nested :Status

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::AutomationManager", :inverse_of => false
  belongs_to :job_template, :foreign_key => :orchestration_template_id, :class_name => "ConfigurationScript", :inverse_of => false
  belongs_to :playbook, :foreign_key => :configuration_script_base_id, :inverse_of => false

  belongs_to :miq_task, :foreign_key => :ems_ref, :inverse_of => false

  #
  # Allowed options are
  #   :limit      => String
  #   :extra_vars => Hash
  #
  def self.create_stack(template, options = {})
    template_ref = template.new_record? ? nil : template
    new(:name                  => template.name,
        :ext_management_system => template.manager,
        :job_template          => template_ref).tap do |stack|
      stack.send(:update_with_provider_object, raw_create_stack(template, options))
    end
  end

  def self.raw_create_stack(template, options = {})
    options = reconcile_extra_vars_keys(template, options)
    template.run(options)
  rescue StandardError => e
    _log.error("Failed to create job from template(#{template.name}), error: #{e}")
    raise MiqException::MiqOrchestrationProvisionError, e.to_s, e.backtrace
  end

  class << self
    alias create_job create_stack
    alias raw_create_job raw_create_stack
  end

  def raw_status
    Status.new(miq_task, nil)
  end

  def raw_stdout(format = 'txt')
    case format
    when "json" then raw_stdout_json
    when "html" then raw_stdout_html
    else             raw_stdout_txt
    end
  end

  def refresh_ems
    update_with_provider_object(self)
  end

  def job_plays
    []
  end

  # Intend to be called by UI to display stdout. The stdout is stored in MiqTask#task_results or #message if error
  # Since the task_results may contain a large block of data, it is desired to remove the task upon receiving the data
  def raw_stdout_via_worker(userid, format = 'txt')
    unless MiqRegion.my_region.role_active?("embedded_ansible")
      msg = "Cannot get standard output of this playbook because the embedded Ansible role is not enabled"
      return MiqTask.create(
        :name    => 'ansible_stdout',
        :userid  => userid || 'system',
        :state   => MiqTask::STATE_FINISHED,
        :status  => MiqTask::STATUS_ERROR,
        :message => msg
      ).id
    end

    options = {:userid => userid || 'system', :action => 'ansible_stdout'}
    queue_options = {
      :class_name  => self.class,
      :method_name => 'raw_stdout',
      :instance_id => id,
      :args        => [format],
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => nil
    }

    MiqTask.generic_action_with_callback(options, queue_options)
  end

  def retireable?
    false
  end

  private

  # If extra_vars are passed through automate, all keys are considered as attributes and
  # converted to lower case. Need to convert them back to original definitions in the
  # job template through survey_spec or variables
  def self.reconcile_extra_vars_keys(_template, options)
    options
  end
  private_class_method :reconcile_extra_vars_keys

  def update_with_provider_object(raw_job)
    self.miq_task ||= raw_job.miq_task

    update_attributes!(
      :status      => miq_task.state,
      :start_time  => miq_task.started_on,
      :finish_time => raw_status.completed? ? miq_task.updated_on : nil
    )
  end

  def raw_stdout_json
    miq_task.context_data[:ansible_runner_stdout]
  end

  def raw_stdout_txt
    raw_stdout_json.collect { |j| j["stdout"] }.join("\n")
  end

  def raw_stdout_html
    TerminalToHtml.render(raw_stdout_txt)
  end
end
