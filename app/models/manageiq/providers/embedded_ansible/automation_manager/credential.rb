class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential < ManageIQ::Providers::EmbeddedAutomationManager::Authentication
  # Authentication is associated with EMS through resource_id/resource_type
  # Alias is to make the AutomationManager code more uniformly as those
  # CUD operations in the TowerApi concern

  alias_attribute :manager_id, :resource_id
  alias_attribute :manager, :resource

  after_create :set_manager_ref

  COMMON_ATTRIBUTES = {}.freeze
  EXTRA_ATTRIBUTES = {}.freeze
  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  FRIENDLY_NAME = "Ansible Automation Inside Credential".freeze

  include ManageIQ::Providers::EmbeddedAnsible::CrudCommon

  def self.params_to_attributes(_params)
    raise NotImplementedError, "must be implemented in a subclass"
  end

  def self.raw_create_in_provider(manager, params)
    create_params = params_to_attributes(params)
    create_params[:resource] = manager
    create!(create_params)
  end

  def raw_update_in_provider(params)
    update!(self.class.params_to_attributes(params.except(:task_id, :miq_task_id)))
  end

  def raw_delete_in_provider
    destroy!
  end

  def native_ref
    Integer(manager_ref)
  end

  def set_manager_ref
    self.manager_ref = self.id
    save!
  end
end
