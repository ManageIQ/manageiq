describe ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher::Stream do
  it_behaves_like 'ansible event_catcher stream',
                  described_class.name.underscore.to_s
end
