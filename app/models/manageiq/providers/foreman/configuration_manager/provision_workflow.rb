class ManageIQ::Providers::Foreman::ConfigurationManager::ProvisionWorkflow < MiqProvisionConfiguredSystemWorkflow
  def self.default_dialog_file
    'miq_provision_configured_system_foreman_dialogs'
  end

  def get_source_and_targets(_refresh = false)
  end

  def update_field_visibility
  end

  # Methods for populating lists of allowed values for a field

  def allowed_configured_systems(_options = {})
    @allowed_configured_systems ||= begin
      ::ConfiguredSystem.where(:id => @values[:src_configured_system_ids]).collect do |cs|
        build_ci_hash_struct(cs, [:configuration_location_name, :configuration_organization_name, :hostname, :operating_system_flavor_name, :provider_name])
      end
    end
  end

  def allowed_configuration_profiles(_options = {})
    @allowed_configuration_profiles ||= begin
      profiles = ::ConfiguredSystem.common_configuration_profiles_for_selected_configured_systems(@values[:src_configured_system_ids])
      profiles.each_with_object({}) do |cp, hash|
        hash[cp.id] = cp.description
      end
    end
  end
end
