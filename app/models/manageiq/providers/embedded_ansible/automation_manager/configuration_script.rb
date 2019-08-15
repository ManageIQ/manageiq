class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScript
  FRIENDLY_NAME = "Embedded Ansible Job Template".freeze

  include ManageIQ::Providers::EmbeddedAnsible::CrudCommon

  def self.params_to_attributes(manager, params)
    playbook = manager.configuration_script_payloads.find_by(:name => params[:playbook])
    raise "Playbook name=#{params[:playbook].inspect} no longer exists" if playbook.nil?

    params = params.except(:playbook)
    variables = params.slice!(:name, :description).to_h.stringify_keys
    params.merge!(
      :manager_id => manager.id,
      :parent_id  => playbook.id,
      :variables  => variables
    )
  end

  def self.raw_create_in_provider(manager, params)
    create!(params_to_attributes(manager, params))
  end

  def raw_update_in_provider(params)
    update_attributes!(self.class.params_to_attributes(manager, params.except(:task_id, :miq_task_id)))
  end

  def raw_delete_in_provider
    destroy!
  end

  def run(vars = {})
    workflow = ManageIQ::Providers::AnsiblePlaybookWorkflow

    extra_vars = merge_extra_vars(vars[:extra_vars])

    playbook_vars = {
      :configuration_script_source_id => parent.configuration_script_source_id,
      :playbook_relative_path         => parent.name
    }

    credentials = collect_credentials(vars)

    kwargs = {:become_enabled => vars[:become_enabled]}
    kwargs[:timeout]   = vars[:execution_ttl].to_i.minutes if vars[:execution_ttl].present?
    kwargs[:verbosity] = vars[:verbosity].to_i             if vars[:verbosity].present?

    workflow.create_job({}, extra_vars, playbook_vars, vars[:hosts], credentials, kwargs).tap do |job|
      job.signal(:start)
    end
  end

  private

  def merge_extra_vars(external)
    extra_vars = variables.merge(external || {}).each_with_object({}) do |(k, v), hash|
      match_data = v.kind_of?(String) && /password::/.match(v)
      hash[k] = match_data ? ManageIQ::Password.decrypt(v.gsub(/password::/, '')) : v
    end

    extra_vars
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
