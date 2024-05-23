class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential < ManageIQ::Providers::EmbeddedAutomationManager::Authentication
  FRIENDLY_NAME = "Embedded Ansible Credential".freeze

  def self.credential_type
    "embedded_ansible_credential_types"
  end

  private_class_method def self.queue_role
    "embedded_ansible"
  end
end
