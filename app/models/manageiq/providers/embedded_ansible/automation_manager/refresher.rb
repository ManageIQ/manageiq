class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Refresher

  def self.display_name(number = 1)
    n_('Credential (Rackspace)', 'Credentials (Rackspace)', number)
  end
end
