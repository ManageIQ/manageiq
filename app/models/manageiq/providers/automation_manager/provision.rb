class ManageIQ::Providers::AutomationManager::Provision < MiqProvisionTask
  def self.request_class
    MiqProvisionConfigurationScriptRequest
  end

  def my_role(*)
    "ems_operations"
  end

  def my_queue_name
    source.manager&.queue_name_for_ems_operations
  end
end
