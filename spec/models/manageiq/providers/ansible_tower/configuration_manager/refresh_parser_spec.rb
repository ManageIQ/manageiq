describe ManageIQ::Providers::AnsibleTower::ConfigurationManager::RefreshParser do
  let(:parser)  { described_class.new }
  let(:hosts)   { [double("host", "id" => 1, "name" => "h1"), double("host", "id" => 2, "name" => "h2")] }

  it "parses hosts" do
    result = parser.configuration_inv_to_hashes(:hosts => hosts)

    expect(result[:configured_systems].count).to eq(2)
    expect(result[:configured_systems].first).to eq(
      :manager_ref => "1",
      :hostname    => "h1",
      :type        => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem"
    )
  end
end
