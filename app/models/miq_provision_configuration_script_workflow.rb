class MiqProvisionConfigurationScriptWorkflow < MiqProvisionWorkflow
  def self.base_model
    MiqProvisionConfigurationScriptWorkflow
  end

  def self.default_dialog_file
    'miq_provision_configuration_script_dialogs'
  end

  def self.automate_dialog_request
    'UI_CONFIGURATION_SCRIPT_PROVISION_INFO'
  end

  def self.request_class
    MiqProvisionConfigurationScriptRequest
  end
end
