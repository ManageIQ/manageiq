# This corresponds to Ansible Tower's Azure Resource Manager (azure_rm) type credential.  We are not modeling the deprecated Azure classic
class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AzureCredential <
  ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
end
