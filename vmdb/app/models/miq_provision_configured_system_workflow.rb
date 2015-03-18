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

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
Dir.glob(File.join(File.dirname(__FILE__), "miq_provision_configured_system_*_workflow.rb")).each { |f| require_dependency f }
