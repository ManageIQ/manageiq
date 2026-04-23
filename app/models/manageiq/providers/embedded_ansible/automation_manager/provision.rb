class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Provision < ManageIQ::Providers::AutomationManager::Provision
  include StateMachine

  TASK_DESCRIPTION = N_("Ansible Playbook Provision")
end
