module ManageIQ::Providers::EmbeddedAnsible::AutomationManager::EventParser
  extend ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::EventParser

  def self.source
    "EMBEDDEDANSIBLE"
  end
end
