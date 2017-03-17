require 'support/ansible_shared/automation_manager/event_catcher/stream'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher::Stream do
  it_behaves_like 'ansible event_catcher stream',
                  described_class.name.underscore.to_s
end
