class ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptPayload <
  ManageIQ::Providers::AutomationManager::ConfigurationScriptPayload

  include AnsiblePlaybookMixin

  # create ServiceTemplate and supporting ServiceResources and ResourceActions
  # options
  #   :name
  #   :description
  #   :config_info
  #     :variables
  #     :hosts
  #     :credential_id
  #     :network_credential_id
  #     :cloud_credential_id
  #     :playbook_id
  #
  def self.run(options, auth_user = nil)
    auth_user ||= 'system'
    name = options[:name]
    description = options[:description]
    info = options[:config_info]
    results, tower_id = ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptPayload.send(:create_job_template, build_name(name), description, info, auth_user)
    launch(results, tower_id, auth_user)
  end

  def self.launch(results, tower_id, auth_user)
    task_id = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript.launch_in_provider_queue(tower_id, results.id, results.name, auth_user)
    task = MiqTask.wait_for_taskid(task_id)
    raise task.message unless task.status == "Ok"
    task.task_results
  end

  def self.build_name(basic_name)
    "#{basic_name}_#{Time.zone.now.to_i}"
  end
  private_class_method :build_name

  def self.build_parameter_list(name, description, info)
    playbook = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook.find(info[:playbook_id])
    tower = playbook.manager
    params = {
      :name           => name,
      :description    => description || '',
      :project        => playbook.configuration_script_source.manager_ref,
      :playbook       => playbook.name,
      :inventory      => info[:inventory],
      :become_enabled => info[:become_enabled].present?,
      :verbosity      => info[:verbosity].presence || 0,
    }
    if info[:extra_vars]
      params[:extra_vars] = info[:extra_vars].transform_values do |val|
        val.kind_of?(String) ? val : val[:default] # TODO: support Hash only
      end.to_json
    end

    [:credential, :cloud_credential, :network_credential].each do |credential|
      cred_sym = "#{credential}_id".to_sym
      params[credential] = Authentication.find(info[cred_sym]).manager_ref if info[cred_sym]
    end

    [tower, params.compact]
  end
  private_class_method :build_parameter_list
end
