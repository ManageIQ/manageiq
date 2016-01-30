describe ManageIQ::Providers::Openstack::InfraManager::Refresher do
  it ".ems_type" do
    expect(described_class.ems_type).to eq(:openstack_infra)
  end
end
