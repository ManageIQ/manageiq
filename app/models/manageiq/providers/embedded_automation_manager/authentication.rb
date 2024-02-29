class ManageIQ::Providers::EmbeddedAutomationManager::Authentication < ManageIQ::Providers::AutomationManager::Authentication
  # Authentication is associated with EMS through resource_id/resource_type
  # Alias is to make the Authentication code more consistent with the
  # other models

  alias_attribute :manager_id, :resource_id
  alias_attribute :manager, :resource

  after_create :set_manager_ref

  supports :create
  supports :update
  supports :delete

  COMMON_ATTRIBUTES = {}.freeze
  EXTRA_ATTRIBUTES = {}.freeze
  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  def self.display_name(number = 1)
    n_('Credential', 'Credentials', number)
  end

  include ManageIQ::Providers::EmbeddedAutomationManager::CrudCommon

  def self.params_to_attributes(params)
    allowed_params     = self::API_ATTRIBUTES.pluck(:id) + %w[name type options]
    unpermitted_params = params.keys.map(&:to_s) - allowed_params
    raise ArgumentError, _("Invalid parameters: %{params}" % {:params => unpermitted_params.join(", ")}) if unpermitted_params.any?

    params
  end

  def self.raw_create_in_provider(manager, params)
    create_params = params_to_attributes(params)
    create_params[:resource] = manager
    create!(create_params)
  end

  def self.encrypt_queue_params(params)
    options = params.dup
    DDF.traverse(:fields => self::API_ATTRIBUTES) do |field|
      key_path = field[:name].try(:split, '.').try(:map, &:to_sym)
      if options.key_path?(key_path) && field[:type] == 'password'
        options.store_path(key_path, ManageIQ::Password.try_encrypt(options.fetch_path(key_path)))
      end
    end
    options
  end

  def raw_update_in_provider(params)
    update!(params_to_attributes(params))
  end

  def raw_delete_in_provider
    destroy!
  end

  # params for update
  def params_to_attributes(params)
    update_params           = params.dup
    update_params[:options] = options.merge(update_params[:options] || {}) if options
    self.class.params_to_attributes(update_params.except(:task_id, :miq_task_id))
  end

  def native_ref
    Integer(manager_ref)
  end

  def set_manager_ref
    self.manager_ref = id
    save!
  end

  private

  def ensure_newline_for_ssh_key
    self.auth_key = "#{auth_key}\n" if auth_key.present? && auth_key[-1] != "\n"
  end
end
