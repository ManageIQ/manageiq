describe ManageIQ::Providers::AnsibleTower::Provider do
  subject { FactoryGirl.create(:provider_ansible_tower) }

  it_behaves_like 'ansible provider'
end
