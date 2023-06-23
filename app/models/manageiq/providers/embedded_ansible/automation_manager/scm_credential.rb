class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ScmCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential
  include ManageIQ::Providers::EmbeddedAutomationManager::ScmCredentialMixin

  FRIENDLY_NAME = "Embedded Ansible Credential".freeze
end
