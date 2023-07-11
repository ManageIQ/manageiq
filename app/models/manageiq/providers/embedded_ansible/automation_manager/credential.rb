class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential < ManageIQ::Providers::EmbeddedAutomationManager::Authentication
  FRIENDLY_NAME = "Embedded Ansible Credential".freeze

  private_class_method def self.queue_role
    "embedded_ansible"
  end
end
