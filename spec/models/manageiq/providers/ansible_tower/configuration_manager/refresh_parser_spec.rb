describe ManageIQ::Providers::AnsibleTower::ConfigurationManager::RefreshParser do
  let(:connection) { double(:connection, :api => double(:api, :hosts => double(:hosts, :all => all_hosts))) }
  let(:parser)     { described_class.new(manager) }
  let(:manager)    { FactoryGirl.create(:configuration_manager_ansible_tower, :provider) }
  let(:all_hosts)  { [double("host", "id" => 1, "name" => "h1"), double("host", "id" => 2, "name" => "h2")] }

  it "#configuration_manager_inv_to_hashes" do
    expect(manager.provider).to receive(:connect).and_return(connection)

    parser.configuration_manager_inv_to_hashes

    expect(parser.instance_variable_get(:@data)[:configured_systems].count).to eq(2)
    expect(parser.instance_variable_get(:@data)[:configured_systems].first).to eq(
      :manager_ref => "1",
      :hostname    => "h1",
      :type        => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem"
    )
  end
end
