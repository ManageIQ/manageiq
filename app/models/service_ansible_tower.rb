class ServiceAnsibleTower < Service
  include ServiceConfigurationMixin

  alias_method :job_template, :configuration_script
  alias_method :job_template=, :configuration_script=

  def launch_job
    @job = ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job.create_job(job_template, {})
    add_resource(@job)
    @job
  ensure
    # create options may never be saved before unless they were overridden
    save_launch_options
  end

  def job
    @job ||= service_resources.find { |sr| sr.resource.kind_of?(OrchestrationStack) }.try(:resource)
  end

  private

  def save_launch_options
    # TODO
    save!
  end
end
