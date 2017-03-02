module ManageIQ::Providers::AnsibleTower::AutomationManager::EventParser
  extend ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::EventParser

  def self.source
    "ANSIBLE_TOWER"
  end
end
