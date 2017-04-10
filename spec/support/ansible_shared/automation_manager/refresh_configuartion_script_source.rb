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
    configuration_script_source = automation_manager.configuration_script_sources.create(
      :manager_ref => 472
    )
    configuration_script_source_other = automation_manager.configuration_script_sources.create(
      :manager_ref => 5,
      :name        => 'Dont touch this'
    )

    2.times do
      VCR.use_cassette(cassette_path) do
        EmsRefresh.refresh(configuration_script_source)
        expect(automation_manager.reload.last_refresh_error).to be_nil
        expect(automation_manager.configuration_script_sources.count).to eq(2)

        configuration_script_source.reload
        configuration_script_source_other.reload

        expect(configuration_script_source.name).to eq("targeted_refresh")
        expect(ConfigurationScriptPayload.count).to eq(81)
        expect(configuration_script_source.configuration_script_payloads.count).to eq(81)

        expect(configuration_script_source_other.name).to eq("Dont touch this")
      end
      # check it was added back on the second run
      configuration_script_source.configuration_script_payloads.where(:name => "test/utils/docker/httptester/httptester.yml").destroy_all
    end
  end
end
