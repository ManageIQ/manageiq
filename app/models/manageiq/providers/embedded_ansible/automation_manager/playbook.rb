class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptPayload
  has_many :jobs, :class_name => 'OrchestrationStack', :foreign_key => :configuration_script_base_id

  def self.display_name(number = 1)
    n_('Playbook (Embedded Ansible)', 'Playbooks (Embedded Ansible)', number)
  end

  def run(vars = {})
    workflow = ManageIQ::Providers::AnsiblePlaybookWorkflow

    extra_vars = build_extra_vars(vars[:extra_vars])

    playbook_vars = {
      :configuration_script_source_id => configuration_script_source_id,
      :playbook_relative_path         => name
    }

    credentials = collect_credentials(vars)

    kwargs = {:become_enabled => vars[:become_enabled]}
    kwargs[:timeout]   = vars[:execution_ttl].to_i.minutes
    kwargs[:verbosity] = vars[:verbosity].to_i if vars[:verbosity].present?

    workflow.create_job({}, extra_vars, playbook_vars, vars[:hosts], credentials, kwargs).tap do |job|
      job.signal(:start)
    end
  end

  private

  def build_extra_vars(external = {})
    (external || {}).each_with_object({}) do |(k, v), hash|
      match_data = v.kind_of?(String) && /password::/.match(v)
      hash[k] = match_data ? ManageIQ::Password.decrypt(v.gsub(/password::/, '')) : v
    end
  end

  def collect_credentials(options)
    options.values_at(
      :credential,
      :cloud_credential,
      :network_credential,
      :vault_credential
    ).compact
  end
end
