describe ManageIQ::Providers::AnsibleTower::AutomationManager::Refresher do
  # To re-record cassettes or to add cassettes you can add another inner `VCR.use_cassette` block to the
  # 'will perform a full refresh' example. When running specs, new requests are recorded to the innermost cassette and
  # can be played back from  any level of nesting (it tries the innermost cassette first, then searches up the parent
  # chain) - http://stackoverflow.com/a/13425826
  #
  # To add a new cassette
  #   * add another block (innermost) with an empty cassette
  #   * change existing cassettes to use your working credentials
  #   * run the specs to create a new cassette
  #   * change new and existing cassettes to use default credentials
  #
  # To re-record a cassette
  #   * temporarily make the cassette the innermost one (see above about recording)
  #   * rm cassette ; run specs
  #   * change back the order of cassettes
  #
  # To change credentials in cassettes:
  # replace with defaults - before committing
  # ruby -pi -e 'gsub /yourdomain.com/, "example.com"; gsub /admin:smartvm/, "testuser:secret"' spec/vcr_cassettes/manageiq/providers/ansible_tower/automation_manager/*.yml
  # replace with your working credentials
  # ruby -pi -e 'gsub /example.com/, "yourdomain.com"; gsub /testuser:secret/, "admin:smartvm"' spec/vcr_cassettes/manageiq/providers/ansible_tower/automation_manager/*.yml

  let(:tower_url) { ENV['TOWER_URL'] || "https://dev-ansible-tower3.example.com/api/v1/" }
  let(:auth_userid) { ENV['TOWER_USER'] || 'testuser' }
  let(:auth_password) { ENV['TOWER_PASSWORD'] || 'secret' }

  let(:auth)                    { FactoryGirl.create(:authentication, :userid => auth_userid, :password => auth_password) }
  let(:automation_manager)      { provider.automation_manager }
  let(:expected_counterpart_vm) { FactoryGirl.create(:vm, :uid_ems => "4233080d-7467-de61-76c9-c8307b6e4830") }
  let(:provider) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:provider_ansible_tower,
                       :zone       => zone,
                       :url        => tower_url,
                       :verify_ssl => false,).tap { |provider| provider.authentications << auth }
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ansible_tower_automation)
  end

  it "will perform a full refresh" do
    expected_counterpart_vm

    2.times do
      # to re-record cassettes see comment at the beginning of this file
      VCR.use_cassette(described_class.name.underscore) do
        VCR.use_cassette(described_class.name.underscore + '_configuration_script_sources') do
          VCR.use_cassette(described_class.name.underscore + '_credentials') do
            EmsRefresh.refresh(automation_manager)
            expect(automation_manager.reload.last_refresh_error).to be_nil
          end
        end
      end

      assert_counts
      assert_configured_system
      assert_configuration_script_with_nil_survey_spec
      assert_configuration_script_with_survey_spec
      assert_inventory_root_group
      assert_configuration_script_sources
      assert_playbooks
      assert_credentials
    end
  end

  def assert_counts
    expect(Provider.count).to                                    eq(1)
    expect(automation_manager).to                             have_attributes(:api_version => "3.0.1")
    expect(automation_manager.configured_systems.count).to    eq(84)
    expect(automation_manager.configuration_scripts.count).to eq(11)
    expect(automation_manager.inventory_groups.count).to      eq(6)
    expect(automation_manager.configuration_script_sources.count).to eq(6)
    expect(automation_manager.configuration_script_payloads.count).to eq(438)
    expect(automation_manager.credentials.count).to eq(8)
  end

  def assert_credentials
    expect(expected_configuration_script.authentications.count).to eq(3)
    machine_credential = expected_configuration_script.authentications.find_by(
      :type => ManageIQ::Providers::AnsibleTower::AutomationManager::MachineCredential
    )
    expect(machine_credential).to have_attributes(
      :name   => "Demo Credential",
      :userid => "admin",
    )
    network_credential = expected_configuration_script.authentications.find_by(
      :type => ManageIQ::Providers::AnsibleTower::AutomationManager::NetworkCredential
    )
    expect(network_credential).to have_attributes(
      :name   => "Demo Creds 2",
      :userid => "awdd",
    )
    cloud_credential = expected_configuration_script.authentications.find_by(
      :type => ManageIQ::Providers::AnsibleTower::AutomationManager::VmwareCredential
    )
    expect(cloud_credential).to have_attributes(
      :name   => "dev-vc60",
      :userid => "MiqAnsibleUser@vsphere.local",
    )
  end

  def assert_playbooks
    expect(expected_configuration_script_source.configuration_script_payloads.first).to be_an_instance_of(ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook)
    expect(expected_configuration_script_source.configuration_script_payloads.count).to eq(1)
    expect(expected_configuration_script_source.configuration_script_payloads.map(&:name)).to include('hello_world.yml')
  end

  def assert_configuration_script_sources
    expect(automation_manager.configuration_script_sources.count).to eq(6)
    expect(expected_configuration_script_source).to be_an_instance_of(ConfigurationScriptSource)
    expect(expected_configuration_script_source).to have_attributes(
      :name        => 'Demo Project',
      :description => 'A great demo',
    )
  end

  def assert_configured_system
    expect(expected_configured_system).to have_attributes(
      :type                 => "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem",
      :hostname             => "Ansible-Host",
      :manager_ref          => "3",
      :virtual_instance_ref => "4233080d-7467-de61-76c9-c8307b6e4830",
    )
    expect(expected_configured_system.counterpart).to          eq(expected_counterpart_vm)
    expect(expected_configured_system.inventory_root_group).to eq(expected_inventory_root_group)
  end

  def assert_configuration_script_with_nil_survey_spec
    expect(expected_configuration_script).to have_attributes(
      :description => "Ansible-JobTemplate-Description",
      :manager_ref => "80",
      :name        => "Ansible-JobTemplate",
      :survey_spec => {},
      :variables   => {'abc' => 123},
    )
    expect(expected_configuration_script.inventory_root_group).to have_attributes(:ems_ref => "2")
  end

  def assert_configuration_script_with_survey_spec
    system = automation_manager.configuration_scripts.where(:name => "Ansible-JobTemplate-Survey").first
    expect(system).to have_attributes(
      :name        => "Ansible-JobTemplate-Survey",
      :description => "Ansible-JobTemplate-Description",
      :manager_ref => "81",
      :variables   => {'abc' => 123}
    )
    survey = system.survey_spec
    expect(survey).to be_a Hash
    expect(survey['spec'].first['question_name']).to eq('Survey')
  end

  def assert_inventory_root_group
    expect(expected_inventory_root_group).to have_attributes(
      :name    => "Dev-VC60",
      :ems_ref => "2",
      :type    => "ManageIQ::Providers::AutomationManager::InventoryRootGroup",
    )
  end

  private

  def expected_configured_system
    @expected_configured_system ||= automation_manager.configured_systems.where(:hostname => "Ansible-Host").first
  end

  def expected_configuration_script
    @expected_configuration_script ||= automation_manager.configuration_scripts.where(:name => "Ansible-JobTemplate").first
  end

  def expected_inventory_root_group
    @expected_inventory_root_group ||= automation_manager.inventory_groups.where(:name => "Dev-VC60").first
  end

  def expected_configuration_script_source
    @expected_configuration_script_source ||= automation_manager.configuration_script_sources.find_by(:name => 'Demo Project')
  end
end
