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
      assert_configuration_script_with_nil_survey_spec
      assert_configuration_script_with_survey_spec
      assert_inventory_root_group
    end
  end

  def assert_counts
    expect(Provider.count).to                                    eq(1)
    expect(configuration_manager).to                             have_attributes(:api_version => "2.4.2")
    expect(configuration_manager.configured_systems.count).to    eq(75)
    expect(configuration_manager.configuration_scripts.count).to eq(7)
    expect(configuration_manager.inventory_groups.count).to      eq(7)
  end

  def assert_configured_system
    expect(expected_configured_system).to have_attributes(
      :type                 => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem",
      :hostname             => "Ansible-Host",
      :manager_ref          => "48",
      :virtual_instance_ref => "4233080d-7467-de61-76c9-c8307b6e4830",
    )
    expect(expected_configured_system.inventory_root_group).to eq(expected_inventory_root_group)
  end

  def assert_configuration_script_with_nil_survey_spec
    expect(expected_configuration_script).to have_attributes(
      :name        => "Ansible-JobTemplate",
      :description => "Ansible-JobTemplate-Description",
      :manager_ref => "149",
      :variables   => "{\n \"abc\": 123\n}",
      :survey_spec => nil
    )
  end

  def assert_configuration_script_with_survey_spec
    system = configuration_manager.configuration_scripts.where(:name => "Ansible-JobTemplate-Survey").first
    expect(system).to have_attributes(
      :name        => "Ansible-JobTemplate-Survey",
      :description => "Ansible-JobTemplate-Description",
      :manager_ref => "155",
      :variables   => "{\n \"abc\": 123\n}"
    )
    survey = JSON.parse(system.survey_spec)
    expect(survey).to be_a Hash
    expect(survey['spec'].first['index']).to eq 0
  end

  def assert_inventory_root_group
    expect(expected_inventory_root_group).to have_attributes(
      :name    => "VC 6.0",
      :ems_ref => "5",
      :type    => "ManageIQ::Providers::ConfigurationManager::InventoryRootGroup",
    )
  end

  private

  def expected_configured_system
    @expected_configured_system ||= configuration_manager.configured_systems.where(:hostname => "Ansible-Host").first
  end

  def expected_configuration_script
    @expected_configuration_script ||= configuration_manager.configuration_scripts.where(:name => "Ansible-JobTemplate").first
  end

  def expected_inventory_root_group
    @expected_inventory_root_group ||= configuration_manager.inventory_groups.where(:name => "VC 6.0").first
  end
end
