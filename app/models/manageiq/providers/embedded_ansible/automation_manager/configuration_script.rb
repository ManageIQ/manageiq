class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScript
  FRIENDLY_NAME = "Ansible Automation Inside Job Template".freeze

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
end
