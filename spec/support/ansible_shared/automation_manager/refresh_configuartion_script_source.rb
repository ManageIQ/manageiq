shared_examples_for "refresh configuration_script_source" do |ansible_provider, manager_class, _ems_type, cassette_path|
  let(:tower_url) { ENV['TOWER_URL'] || "https://dev-ansible-tower3.example.com/api/v1/" }
  let(:auth_userid) { ENV['TOWER_USER'] || 'testuser' }
  let(:auth_password) { ENV['TOWER_PASSWORD'] || 'secret' }

  let(:auth)                    { FactoryGirl.create(:authentication, :userid => auth_userid, :password => auth_password) }
  let(:automation_manager)      { provider.automation_manager }
  let(:provider) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(ansible_provider,
                       :zone       => zone,
                       :url        => tower_url,
                       :verify_ssl => false,).tap { |provider| provider.authentications << auth }
  end
  let(:manager_class) { manager_class }

  it "will perform a targeted refresh" do
    # TODO: use this factory if running for embedded tower
    # factory :embedded_ansible_configuration_script_source,
    configuration_script_source = FactoryGirl.create(:ansible_configuration_script_source,
                                                     :manager     => automation_manager,
                                                     :manager_ref => 472)
    configuration_script_source.configuration_script_payloads.create!(:manager_ref => '2b_rm', :name => '2b_rm')
    configuration_script_source_other = FactoryGirl.create(:ansible_configuration_script_source,
                                                           :manager_ref => 5,
                                                           :manager     => automation_manager,
                                                           :name        => 'Dont touch this')

    # When re-recording the cassetes, comment this to default to normal poll sleep time
    stub_const("ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScriptSource::REFRESH_ON_TOWER_SLEEP", 0.seconds)

    # this is to check if a project will be updated on tower
    last_project_update = Time.zone.parse("2017-04-10 20:50:11.429285000 +0000") - 1.minute

    2.times do
      VCR.use_cassette(cassette_path) do
        EmsRefresh.refresh(configuration_script_source)

        expect(automation_manager.reload.last_refresh_error).to be_nil
        expect(automation_manager.configuration_script_sources.count).to eq(2)

        configuration_script_source.reload
        configuration_script_source_other.reload

        last_updated = Time.zone.parse(configuration_script_source.provider_object.last_updated)
        expect(last_updated).to be >= last_project_update
        last_project_update = last_updated

        expect(configuration_script_source.name).to eq("targeted_refresh")
        expect(ConfigurationScriptPayload.count).to eq(81)
        expect(configuration_script_source.configuration_script_payloads.count).to eq(81)

        expect(configuration_script_source_other.name).to eq("Dont touch this")
      end
      # check if a playbook will be added back in on the second run
      configuration_script_source.configuration_script_payloads.where(:name => "test/utils/docker/httptester/httptester.yml").destroy_all
    end
  end
end
