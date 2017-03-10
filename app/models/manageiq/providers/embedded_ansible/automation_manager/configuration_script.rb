class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript <
  ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScript

  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScript

  def jobs
    ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job.where(:orchestration_template_id => id)
  end
end
