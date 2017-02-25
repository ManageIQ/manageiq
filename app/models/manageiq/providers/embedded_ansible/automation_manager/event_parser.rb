module ManageIQ::Providers::EmbeddedAnsible::AutomationManager::EventParser
  extend ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::EventParser

  def self.event_type
    "embedded_ansible"
  end

  def self.source
    "EMBEDDED_ANSIBLE"
  end
end
