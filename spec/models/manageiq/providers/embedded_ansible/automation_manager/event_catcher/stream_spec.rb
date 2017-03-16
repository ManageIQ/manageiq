require 'support/ansible_shared/automation_manager/event_catcher/stream'

describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::EventCatcher::Stream do
  it_behaves_like 'ansible event_catcher stream',
                  ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher::Stream.name.underscore.to_s
end
