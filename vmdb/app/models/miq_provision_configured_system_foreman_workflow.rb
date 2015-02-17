class MiqProvisionConfiguredSystemForemanWorkflow < MiqProvisionConfiguredSystemWorkflow
  def self.default_dialog_file
    'miq_provision_configured_system_foreman_dialogs'
  end

  def self.encrypted_options_fields
    [:root_password]
  end

  def supports_iso?
    false
  end

  def create_request(values, requester_id, auto_approve = false)
    event_message = "Provision requested by [#{requester_id}] for Configured Systems:#{values[:src_configured_system_ids].inspect}"
    super(values, requester_id, 'ConfiguredSystem', 'configured_system_provision_request_created', event_message, auto_approve)
  end

  def update_request(request, values, requester_id)
    event_message = "Provision request successfully updated by [#{requester_id}] for Configured Systems:#{values[:src_configured_system_ids].inspect}"
    super(request, values, requester_id, 'ConfiguredSystem', 'configured_system_provision_request_updated', event_message)
  end

  def get_source_and_targets(_refresh = false)
  end

  def update_field_visibility
  end

  # Methods for populating lists of allowed values for a field

  def allowed_configured_systems(_options = {})
    @allowed_configured_systems ||= begin
      ConfiguredSystem.where(:id => @values[:src_configured_system_ids]).collect do |cs|
        build_ci_hash_struct(cs, [:hostname])
      end
    end
  end

  def allowed_configuration_profiles(_options = {})
    @allowed_configuration_profiles ||= begin
      configured_system_ids  = get_value(@values[:src_configured_system_ids])
      configuration_managers = ConfiguredSystem.where(:id => configured_system_ids).collect(&:configuration_manager)
      configuration_managers.collect(&:configuration_profiles).flatten.each_with_object({}) do |cp, hash|
        hash[cp.id] = cp.name
      end
    end
  end
end
