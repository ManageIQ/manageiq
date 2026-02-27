class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScript
  def self.manager_class
    module_parent
  end

  def my_zone
    manager&.my_zone
  end
end
