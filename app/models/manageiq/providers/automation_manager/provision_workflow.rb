class ManageIQ::Providers::AutomationManager::ProvisionWorkflow < MiqProvisionConfigurationScriptWorkflow
  def dialog_name_from_automate(message = 'get_dialog_name', extra_attrs = {})
    extra_attrs['platform_category'] ||= 'automation_manager'
    super(message, %i[request_type], extra_attrs)
  end
end
