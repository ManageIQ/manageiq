class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
  include ::EmsRefresh::Refreshers::EmsRefresherMixin
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Refresher
end
