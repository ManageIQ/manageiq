class ServiceAnsibleTower < Service
  include ServiceConfigurationMixin
  include ServiceOrchestrationOptionsMixin

  alias_method :job_template, :configuration_script
  alias_method :job_template=, :configuration_script=
  alias_method :job_options, :stack_options
  alias_method :job_options=, :stack_options=

  def launch_job
    @job = ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job.create_job(job_template, job_options)
    add_resource(@job)
    @job
  ensure
    # create options may never be saved before unless they were overridden
    save_launch_options
  end

  def job
    @job ||= service_resources.find { |sr| sr.resource.kind_of?(OrchestrationStack) }.try(:resource)
  end

  def build_stack_options_from_dialog(dialog_options)
    {:extra_vars => extra_vars_from_dialog(dialog_options)}.tap do |launch_options|
      launch_options[:limit] = dialog_options['dialog_limit'] unless dialog_options['dialog_limit'].blank?
    end
  end

  private

  # the method name is required by ServiceOrchestrationOptionMixin
  def build_stack_create_options
    # job template from dialog_options overrides the one copied from service_template
    dialog_options = options[:dialog] || {}
    if dialog_options['dialog_job_template']
      self.job_template = ConfigurationScript.find(dialog_options['dialog_job_template'])
    end

    raise _("job template was not set") if job_template.nil?

    build_stack_options_from_dialog(options[:dialog])
  end

  def save_launch_options
    options[:create_options] = dup_and_process_password(job_options)
    save!
  end

  PARAM_PREFIX = 'dialog_param_'.freeze
  PARAM_PREFIX_LEN = PARAM_PREFIX.size
  PASSWORD_PREFIX = 'password::dialog_param_'.freeze
  PASSWORD_PREFIX_LEN = PASSWORD_PREFIX.size

  def extra_vars_from_dialog(dialog_options)
    params = {}

    dialog_options.each do |attr, val|
      if attr.start_with?(PARAM_PREFIX)
        params[attr[PARAM_PREFIX_LEN..-1]] = val
      elsif attr.start_with?(PASSWORD_PREFIX)
        params[attr[PASSWORD_PREFIX_LEN..-1]] = MiqPassword.decrypt(val)
      end
    end
    params
  end
end
