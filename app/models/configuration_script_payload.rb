class ConfigurationScriptPayload < ConfigurationScriptBase
  acts_as_miq_taggable

  belongs_to :configuration_script_source

  def self.base_model
    ConfigurationScriptPayload
  end
end
