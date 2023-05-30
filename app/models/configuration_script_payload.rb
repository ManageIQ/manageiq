class ConfigurationScriptPayload < ConfigurationScriptBase
  acts_as_miq_taggable

  belongs_to :configuration_script_source

  def self.base_model
    ConfigurationScriptPayload
  end

  def run(*)
    raise NotImplementedError, _("run must be implemented in a subclass")
  end
end
