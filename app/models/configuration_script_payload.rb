class ConfigurationScriptPayload < ConfigurationScriptBase
  belongs_to :configuration_script_source

  def self.base_model
    ConfigurationScriptPayload
  end
end
