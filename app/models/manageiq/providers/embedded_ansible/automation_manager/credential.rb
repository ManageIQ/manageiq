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

  FRIENDLY_NAME = "Embedded Ansible Credential".freeze

  include ManageIQ::Providers::EmbeddedAnsible::CrudCommon

  def self.params_to_attributes(_params)
    raise NotImplementedError, "must be implemented in a subclass"
  end

  def self.raw_create_in_provider(manager, params)
    create_params = params_to_attributes(params)
    create_params[:resource] = manager
    create!(create_params)
  end

  def self.password_attribute_keys
    self::API_ATTRIBUTES.map do |k, v|
      k if v[:type] == :password
    end.compact
  end

  def self.encrypt_queue_params(params)
    encrypted_params = params.slice(*password_attribute_keys)
    encrypted_params.transform_values! { |v| ManageIQ::Password.try_encrypt(v) }
    params.merge(encrypted_params)
  end

  def raw_update_in_provider(params)
    update!(params_for_update(params))
  end

  def raw_delete_in_provider
    destroy!
  end

  def params_for_update(params)
    update_params           = params.dup
    update_params[:options] = options.merge(update_params[:options] || {}) if options
    self.class.params_to_attributes(update_params.except(:task_id, :miq_task_id))
  end

  def native_ref
    Integer(manager_ref)
  end

  def set_manager_ref
    self.manager_ref = self.id
    save!
  end

  private

  def ensure_newline_for_ssh_key
    self.auth_key = "#{auth_key}\n" if auth_key.present? && auth_key[-1] != "\n"
  end
end
