module ManageIQ::Providers::AnsibleTower::AutomationManager::EventParser
  extend ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::EventParser

  def self.source
    "ANSIBLETOWER"
  end
end
