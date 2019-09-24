class MiqProvisionConfiguredSystemWorkflow < MiqProvisionWorkflow
  def self.base_model
    MiqProvisionConfiguredSystemWorkflow
  end

  def self.automate_dialog_request
    'UI_CONFIGURED_SYSTEM_PROVISION_INFO'
  end

  def self.request_class
    MiqProvisionConfiguredSystemRequest
  end
end
