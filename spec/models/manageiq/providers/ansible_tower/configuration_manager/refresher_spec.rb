describe ManageIQ::Providers::AnsibleTower::ConfigurationManager::Refresher do
  let(:auth)                  { FactoryGirl.create(:authentication) }
  let(:configuration_manager) { provider.configuration_manager }
  let(:provider) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:provider_ansible_tower,
                       :zone       => zone,
                       :url        => "https://dev-ansible-tower2.example.com/api/v1/",
                       :verify_ssl => false,
                      ).tap { |provider| provider.authentications << auth }
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ansible_tower_configuration)
  end

  it "will perform a full refresh" do
    2.times do
      VCR.use_cassette(described_class.name.underscore) do
        EmsRefresh.refresh(configuration_manager)
        expect(configuration_manager.reload.last_refresh_error).to be_nil
      end

      assert_counts
      assert_configured_system
    end
  end

  def assert_counts
    expect(Provider.count).to                                 eq(1)
    expect(configuration_manager).to                          have_attributes(:api_version => "2.4.2")
    expect(configuration_manager.configured_systems.count).to eq(48)
  end

  def assert_configured_system
    system = configuration_manager.configured_systems.where(:hostname => "Ansible-Host").first

    expect(system).to have_attributes(
      :type        => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem",
      :hostname    => "Ansible-Host",
      :manager_ref => "48",
    )
  end
end
