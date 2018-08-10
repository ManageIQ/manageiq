class ManageIQ::Providers::EmbeddedAutomationManager < ManageIQ::Providers::AutomationManager
  require_nested_all

  def supported_catalog_types
    %w(generic_ansible_playbook)
  end
end
