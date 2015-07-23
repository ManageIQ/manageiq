require "spec_helper"

describe ManageIQ::Providers::Foreman::ConfigurationManager::Refresher do
  before do
    unless provider.api_cached?
      VCR.use_cassette("ems_refresh/refreshers/foreman_refresher_api_doc") do
        provider.ensure_api_cached
      end
    end
  end

  let(:spec_related) { "name like 'ProviderRefreshSpec%'" }
  let(:provider) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:provider_foreman,
                       :zone       => zone,
                       :url        => "example.com",
                       :verify_ssl => false,
                      )
  end

  let(:provisioning_manager)  { provider.provisioning_manager }
  let(:osfs)                  { provisioning_manager.operating_system_flavors }
  let(:customization_scripts) { provisioning_manager.customization_scripts }
  let(:media)                 { provisioning_manager.customization_script_media }
  let(:ptables)               { provisioning_manager.customization_script_ptables }
  let(:configuration_manager) { provider.configuration_manager }
  let(:default_location)      { provisioning_manager.configuration_locations.first }
  let(:default_organization)  { provisioning_manager.configuration_organizations.first }

  let(:architectures)         { provisioning_manager.configuration_architectures }
  let(:compute_profiles)      { provisioning_manager.configuration_compute_profiles }
  let(:domains)               { provisioning_manager.configuration_domains }
  let(:environments)          { provisioning_manager.configuration_environments }
  let(:realms)                { provisioning_manager.configuration_realms }

  let(:my_env)                { environments.select  { |a| a.name = 'production' }.last }
  let(:my_arch)               { architectures.select { |a| a.name = 'x86_64' }.last }

  it "will perform a full refresh on api v2" do
    # Stub the queueing of the refresh so that when the manager
    #  queues up an alternate refresh we will execute it immediately.
    EmsRefresh.stub(:queue_refresh) { |*args| EmsRefresh.refresh(*args) }

    VCR.use_cassette("#{described_class.name.underscore}_api_v2") do
      EmsRefresh.refresh(configuration_manager)
      expect(configuration_manager.reload.last_refresh_error).to be_nil
      expect(provisioning_manager.reload.last_refresh_error).to be_nil
    end

    assert_provider_counts

    assert_provisioning_table_counts
    assert_ptables
    assert_media
    assert_osf
    assert_loc_org
    assert_configuration_tags

    assert_configuration_table_counts
    assert_configuration_profile_parent
    assert_configuration_profile_child
    assert_configured_system
  end

  def assert_provider_counts
    expect(Provider.count).to            eq(1)
    expect(configuration_manager).not_to be_nil
    expect(provisioning_manager).not_to  be_nil
  end

  def assert_provisioning_table_counts
    expect(media.count).to   eq(8)
    expect(ptables.count).to eq(11)
    expect(osfs.count).to    eq(5)
  end

  def assert_media
    medium = mine(media)
    expect(medium).to have_attributes(
      :name        => "ProviderRefreshSpec-Media",
      :type        => "CustomizationScriptMedium",
      :manager_ref => "8"
    )
  end

  def assert_ptables
    ptable = mine(ptables)
    expect(ptable).to have_attributes(
      :name        => "ProviderRefreshSpec-PartitionTable",
      :type        => "CustomizationScriptPtable",
      :manager_ref => "12"
    )
  end

  def assert_osf
    osf = mine(osfs)
    expect(osf).to have_attributes(
      :name        => "ProviderRefreshSpec-OperatingSystem 1.2",
      :description => "OS 1.2",
      :manager_ref => "4"
    )
    expect(osf.customization_scripts).to            match_array [mine(ptables), mine(media)]
    expect(osf.customization_script_ptables).to     match_array [mine(ptables)]
    expect(osf.customization_script_ptables).not_to include(mine(media))
    expect(osf.customization_script_media).to       match_array [mine(media)]
    expect(osf.customization_script_media).not_to   include(mine(ptables))
  end

  def assert_loc_org
    expect(provisioning_manager.configuration_locations.count).to     eq(1)
    expect(provisioning_manager.configuration_organizations.count).to eq(1)
  end

  def assert_configuration_tags
    expect(architectures.count).to eq(2)
    expect(compute_profiles.count).to eq(3)
    expect(domains.count).to eq(1)
    expect(environments.count).to eq(1)
    expect(realms.count).to eq(0)
  end

  def assert_configuration_table_counts
    expect(configuration_manager.configured_systems.count).to     eq(39)
    expect(configuration_manager.configuration_profiles.count).to eq(14)
  end

  def assert_configuration_profile_child
    child  = configuration_manager.configuration_profiles.where(:name => 'ProviderRefreshSpec-ChildHostGroup').first
    parent = configuration_manager.configuration_profiles.where(:name => 'ProviderRefreshSpec-HostGroup').first
    expect(child).to have_attributes(
      :type                               => "ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile",
      :name                               => "ProviderRefreshSpec-ChildHostGroup",
      :description                        => "ProviderRefreshSpec-HostGroup/ProviderRefreshSpec-ChildHostGroup",
      :manager_ref                        => "14",
      :parent                             => parent,
      :configuration_architecture         => my_arch,
      :configuration_environment          => my_env,
      :configuration_compute_profile      => nil,
      :configuration_domain               => nil,
      :configuration_locations            => [default_location],
      :configuration_organizations        => [default_organization],
      :configuration_realm                => nil,
      :customization_script_medium        => mine(media),   # inherited from parent
      :customization_script_ptable        => mine(ptables), # declared
      :direct_customization_script_medium => nil,           # inherited from parent
      :direct_customization_script_ptable => mine(ptables), # declared
      :direct_operating_system_flavor     => nil,           # inherited from parent
      :operating_system_flavor            => mine(osfs),    # inherited from parent
    )
    expect(child.configuration_tags).to match_array([my_arch, my_env])
  end

  def assert_configuration_profile_parent
    parent = configuration_manager.configuration_profiles.where(:name => 'ProviderRefreshSpec-HostGroup').first
    expect(parent).to have_attributes(
      :type                               => "ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile",
      :name                               => "ProviderRefreshSpec-HostGroup",
      :description                        => "ProviderRefreshSpec-HostGroup",
      :manager_ref                        => "13",
      :parent                             => nil,
      :configuration_architecture         => my_arch,
      :configuration_environment          => my_env,
      :configuration_compute_profile      => nil,
      :configuration_domain               => nil,
      :configuration_locations            => [default_location],
      :configuration_organizations        => [default_organization],
      :configuration_realm                => nil,
      :customization_script_medium        => mine(media),   # declared
      :customization_script_ptable        => nil,           # blank
      :direct_customization_script_medium => mine(media),   # declared
      :direct_customization_script_ptable => nil,           # blank
      :direct_operating_system_flavor     => mine(osfs),    # declared
      :operating_system_flavor            => mine(osfs),    # declared
    )
    expect(parent.configuration_tags).to match_array([my_arch, my_env])
  end

  def assert_configured_system
    child  = configuration_manager.configuration_profiles.where(:name => 'ProviderRefreshSpec-ChildHostGroup').first
    system = configuration_manager.configured_systems.where("hostname like 'providerrefreshspec%'").first

    expect(system).to have_attributes(
      :ipaddress                          => "192.168.169.254",
      :mac_address                        => "00:00:00:00:00:00",
      :type                               => "ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem",
      :hostname                           => "providerrefreshspec-hostbaremetal.example.com",
      :manager_ref                        => "38",
      :configuration_profile              => child,
      :configuration_architecture         => my_arch,
      :configuration_environment          => my_env,
      :configuration_compute_profile      => nil,
      :configuration_domain               => domains.first,
      :configuration_location             => default_location,
      :configuration_organization         => default_organization,
      :configuration_realm                => nil,
      :customization_script_medium        => mine(media),   # inherited from parent
      :customization_script_ptable        => mine(ptables), # declared
      :direct_customization_script_medium => mine(media),   # note: values currently copied to host
      :direct_customization_script_ptable => mine(ptables), # note: values currently copied to host
      :direct_operating_system_flavor     => mine(osfs),    # note: values currently copied to host
      :operating_system_flavor            => mine(osfs),    # inherited from parent
    )
    expect(system.configuration_tags).to match_array([my_arch, my_env, domains.first])
  end

  private

  def mine(collection)
    collection.where(spec_related).first
  end
end
