class PhysicalServerProvisionWorkflow < MiqProvisionConfiguredSystemWorkflow
  def self.base_model
    PhysicalServerProvisionWorkflow
  end

  def self.automate_dialog_request
    'UI_PHYSICAL_SERVER_PROVISION_INFO'
  end

  def self.request_class
    PhysicalServerProvisionRequest
  end

  def self.default_dialog_file
    'physical_server_provision_dialogs'
  end

  def allowed_configured_systems(_options = {})
    @allowed_configured_systems ||= begin
      physical_servers = PhysicalServer.where(:id => @values[:src_configured_system_ids])
      physical_servers.collect do |configured_system|
        build_ci_hash_struct(configured_system, ["name"])
      end
    end
  end

  def allowed_configuration_profiles(_options = {})
    @allowed_configuration_profiles ||= begin
      config_profiles = get_customization_scripts
      config_profiles.each_with_object({}) do |config_profile, hash|
        hash[config_profile.id] = config_profile.name
      end
    end
  end

  def get_source_and_targets(_refresh = false)
  end

  private

  def get_customization_scripts
    customization_scripts = []

    # Retrieve the customization scripts/config patterns associated
    # with the provider that's associated with each physical server
    physical_servers = PhysicalServer.where(:id => @values[:src_configured_system_ids])
    physical_servers.each do |server|
      script = CustomizationScript.where(:manager_id => server.ems_id)
      customization_scripts.push(script)
    end

    customization_scripts.flatten
  end
end
