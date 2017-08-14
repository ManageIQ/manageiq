
shared_examples_for "ansible refresher" do |ansible_provider, manager_class, ems_type, cassette_path|
  # Maintaining cassettes for new specs
  #
  # Option #1
  # ========
  # Update: re-create expected set of Tower objects and re-record cassettes
  # 1. Modify the rake task lib/tasks_private/spec_helper.rake to modify the objects for new spec
  # 2. rake manageiq:providers:ansible_tower:populate_tower
  #    (refer to the task doc for detail)
  # 2. remove the old cassette
  # 3. run the spec to create the cassette
  # 4. update the expectations
  # 5. change credentials in cassettes before commit
  #
  # Option #2
  # ========
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
  #
  # To change credentials in cassettes
  # ==================================
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
    FactoryGirl.create(ansible_provider,
                       :zone       => zone,
                       :url        => tower_url,
                       :verify_ssl => false,).tap { |provider| provider.authentications << auth }
  end
  let(:manager_class) { manager_class }

  it ".ems_type" do
    expect(described_class.ems_type).to eq(ems_type)
  end

  it "will remove all objects if an empty collection is returned by tower" do
    mock_api = double
    mock_collection = double(:all => [])
    allow(mock_api).to receive(:version).and_return('3.0')
    allow(mock_api).to receive_messages(
      :inventories   => mock_collection,
      :hosts         => mock_collection,
      :job_templates => mock_collection,
      :projects      => mock_collection,
      :credentials   => mock_collection,
    )
    allow(automation_manager.provider).to receive_message_chain(:connect, :api).and_return(mock_api)
    automation_manager.configuration_script_sources.create!
    EmsRefresh.refresh(automation_manager)

    expect(ConfigurationScriptSource.count).to eq(0)
  end

  it "will perform a full refresh" do
    expected_counterpart_vm

    2.times do
      # to re-record cassettes see comment at the beginning of this file
      VCR.use_cassette(cassette_path) do
        EmsRefresh.refresh(automation_manager)
        expect(automation_manager.reload.last_refresh_error).to be_nil
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
    expect(Provider.count).to                                 eq(1)
    expect(automation_manager).to                             have_attributes(:api_version => "3.0.1")
    expect(automation_manager.configured_systems.count).to    eq(23)
    expect(automation_manager.configuration_scripts.count).to eq(122)
    expect(automation_manager.inventory_groups.count).to      eq(12)
    expect(automation_manager.configuration_script_sources.count).to eq(29)
    expect(automation_manager.configuration_script_payloads.count).to eq(2078)
    expect(automation_manager.credentials.count).to eq(35)
  end

  def assert_credentials
    expect(expected_configuration_script.authentications.count).to eq(3)

    # machine_credential
    machine_credential = expected_configuration_script.authentications.find_by(
      :type => manager_class::MachineCredential
    )
    expect(machine_credential).to have_attributes(
      :name   => "hello_machine_cred",
      :userid => "admin",
    )
    expect(machine_credential.options.keys).to match_array([:become_method, :become_password, :become_username, :ssh_key_data, :ssh_key_unlock, :vault_password])
    expect(machine_credential.options.keys).to match_array(machine_credential.class::EXTRA_ATTRIBUTES.keys)
    expect(machine_credential.options[:become_method]).to eq('')
    expect(machine_credential.options[:become_username]).to eq('')

    # network_credential
    network_credential = expected_configuration_script.authentications.find_by(
      :type => manager_class::NetworkCredential
    )
    expect(network_credential).to have_attributes(
      :name   => "hello_network_cred",
      :userid => "admin",
    )
    expect(network_credential.options.keys).to match_array([:authorize, :authorize_password, :ssh_key_data, :ssh_key_unlock])

    cloud_credential = expected_configuration_script.authentications.find_by(
      :type => manager_class::AmazonCredential
    )
    expect(cloud_credential).to have_attributes(
      :name   => "hello_aws_cred",
      :userid => "ABC",
    )
    expect(cloud_credential.options.keys).to match_array([:security_token])

    # scm_credential
    scm_credential = expected_configuration_script_source.authentication
    expect(scm_credential).to have_attributes(
      :name   => "hello_scm_cred",
      :userid => "admin"
    )
    expect(scm_credential.options.keys).to match_array([:ssh_key_data, :ssh_key_unlock])

    # other credential types
    openstack_cred = automation_manager.credentials.find_by(:name => 'hello_openstack_cred')
    expect(openstack_cred.type.split('::').last).to eq("OpenstackCredential")
    gce_cred = automation_manager.credentials.find_by(:name => 'hello_gce_cred')
    expect(gce_cred.type.split('::').last).to eq("GoogleCredential")
    rackspace_cred = automation_manager.credentials.find_by(:name => 'hello_rax_cred')
    expect(rackspace_cred.type.split('::').last).to eq("RackspaceCredential")
    azure_cred = automation_manager.credentials.find_by(:name => 'hello_azure_cred')
    expect(azure_cred.type.split('::').last).to eq("AzureCredential")
    azure_classic_cred = automation_manager.credentials.find_by(:name => 'hello_azure_classic_cred')
    expect(azure_classic_cred.type.split('::').last).to eq("AzureClassicCredential")
    satellite6_cred = automation_manager.credentials.find_by(:name => 'hello_sat_cred')
    expect(satellite6_cred.type.split('::').last).to eq("Satellite6Credential")
  end

  def assert_playbooks
    expect(expected_configuration_script_source.configuration_script_payloads.first).to be_an_instance_of(manager_class::Playbook)
    expect(expected_configuration_script_source.configuration_script_payloads.count).to eq(61)
    expect(expected_configuration_script_source.configuration_script_payloads.map(&:name)).to include('jboss-standalone/site.yml')
  end

  def assert_configuration_script_sources
    expect(automation_manager.configuration_script_sources.count).to eq(29)

    expect(expected_configuration_script_source).to be_an_instance_of(manager_class::ConfigurationScriptSource)
    expect(expected_configuration_script_source).to have_attributes(
      :name                 => 'hello_repo',
      :description          => '',
      :scm_type             => 'git',
      :scm_url              => 'https://github.com/jameswnl/ansible-examples',
      :scm_branch           => '',
      :scm_clean            => false,
      :scm_delete_on_update => false,
      :scm_update_on_launch => false,
      :status               => 'successful'
    )
    expect(expected_configuration_script_source.authentication.name).to eq('hello_scm_cred')
  end

  def assert_configured_system
    expect(expected_configured_system).to have_attributes(
      :type                 => manager_class::ConfiguredSystem.name,
      :hostname             => "hello_vm",
      :manager_ref          => "252",
      :virtual_instance_ref => "4233080d-7467-de61-76c9-c8307b6e4830",
    )
    expect(expected_configured_system.counterpart).to          eq(expected_counterpart_vm)
    expect(expected_configured_system.inventory_root_group).to eq(expected_inventory_root_group)
  end

  def assert_configuration_script_with_nil_survey_spec
    expect(expected_configuration_script).to have_attributes(
      :name        => "hello_template",
      :description => "test job",
      :manager_ref => "604",
      :survey_spec => {},
      :variables   => {},
    )
    # expect(expected_configuration_script.inventory_root_group).to have_attributes(:ems_ref => "1")
    expect(expected_configuration_script.parent.name).to eq('hello_world.yml')
    # expect(expected_configuration_script.parent.configuration_script_source.manager_ref).to eq('37')
  end

  def assert_configuration_script_with_survey_spec
    system = automation_manager.configuration_scripts.where(:name => "hello_template_with_survey").first
    expect(system).to have_attributes(
      :name        => "hello_template_with_survey",
      :description => "test job with survey spec",
      :manager_ref => "605",
      :variables   => {}
    )
    survey = system.survey_spec
    expect(survey).to be_a Hash
    expect(survey['spec'].first['question_name']).to eq('example question')
  end

  def assert_inventory_root_group
    expect(expected_inventory_root_group).to have_attributes(
      :name    => "hello_inventory",
      :ems_ref => "115",
      :type    => "ManageIQ::Providers::AutomationManager::InventoryRootGroup",
    )
  end

  private

  def expected_configured_system
    @expected_configured_system ||= automation_manager.configured_systems.where(:hostname => "hello_vm").first
  end

  def expected_configuration_script
    @expected_configuration_script ||= automation_manager.configuration_scripts.where(:name => "hello_template").first
  end

  def expected_inventory_root_group
    @expected_inventory_root_group ||= automation_manager.inventory_groups.where(:name => "hello_inventory").first
  end

  def expected_configuration_script_source
    @expected_configuration_script_source ||= automation_manager.configuration_script_sources.find_by(:name => 'hello_repo')
  end
end
