describe ManageIQ::Providers::Openstack::CloudManager::Refresher do
  it ".ems_type" do
    expect(described_class.ems_type).to eq(:openstack)
  end
end
