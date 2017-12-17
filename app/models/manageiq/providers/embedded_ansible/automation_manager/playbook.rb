class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook <
  ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptPayload

  has_many :jobs, :class_name => 'OrchestrationStack', :foreign_key => :configuration_script_base_id

  def run(options, userid = nil)
    options[:playbook_id] = id
    options[:userid]      = userid || 'system'
    options[:name]        = "Playbook: #{name}"
    miq_job = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::PlaybookRunner.create_job(options)
    miq_job.signal(:start)
    miq_job.miq_task.id
  end

  # return provider raw object
  def raw_create_job_template(options)
    job_template_klass = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript
    job_template_klass.raw_create_in_provider(manager, build_parameter_list(options))
  end

  private

  def build_parameter_list(options)
    params = {
      :name                     => options[:template_name] || "#{name}_#{Time.zone.now.to_i}",
      :description              => options[:description] || '',
      :project                  => configuration_script_source.manager_ref,
      :playbook                 => name,
      :become_enabled           => options[:become_enabled].present?,
      :verbosity                => options[:verbosity].presence || 0,
      :ask_variables_on_launch  => true,
      :ask_limit_on_launch      => true,
      :ask_inventory_on_launch  => true,
      :ask_credential_on_launch => true,
      :limit                    => options[:limit],
      :inventory                => options[:inventory] || manager.provider.default_inventory,
      :extra_vars               => options[:extra_vars].try(:to_json)
    }

    %i(credential cloud_credential network_credential).each do |credential|
      cred_sym = "#{credential}_id".to_sym
      params[credential] = Authentication.find(options[cred_sym]).manager_ref if options[cred_sym]
    end

    params.compact
  end
end
