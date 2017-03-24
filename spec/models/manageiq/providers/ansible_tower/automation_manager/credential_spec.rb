require 'support/ansible_shared/automation_manager/credential'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::ScmCredential do
  let(:manager) do
    FactoryGirl.create(:provider_ansible_tower, :with_authentication).managers.first
  end

  it_behaves_like 'ansible credential'
end
