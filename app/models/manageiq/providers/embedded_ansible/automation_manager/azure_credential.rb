# This corresponds to Ansible Tower's Azure Resource Manager (azure_rm) type credential
class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AzureCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::AzureCredential

  def self.display_name(number = 1)
    n_('Credential (Microsoft Azure)', 'Credentials (Microsoft Azure)', number)
  end
end
