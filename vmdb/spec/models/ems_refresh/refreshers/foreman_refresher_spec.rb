require "spec_helper"

describe EmsRefresh::Refreshers::ForemanRefresher do
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

  it "will perform a full refresh on api v2" do
    # Stub the queueing of the refresh so that when the manager
    #  queues up an alternate refresh we will execute it immediately.
    EmsRefresh.stub(:queue_refresh) { |*args| EmsRefresh.refresh(*args) }

    VCR.use_cassette("#{described_class.name.underscore}_api_v2") do
      EmsRefresh.refresh(provider)
      expect(configuration_manager.reload.last_refresh_error).to be_nil
      expect(provisioning_manager.reload.last_refresh_error).to be_nil
    end

    assert_provider_counts

    assert_provisioning_table_counts
    assert_ptables
    assert_media
    assert_osf
    assert_loc_org

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

  def assert_configuration_table_counts
    expect(configuration_manager.configured_systems.count).to     eq(39)
    expect(configuration_manager.configuration_profiles.count).to eq(14)
  end

  def assert_configuration_profile_child
    child  = configuration_manager.configuration_profiles.where(:name => 'ProviderRefreshSpec-ChildHostGroup').first
    parent = configuration_manager.configuration_profiles.where(:name => 'ProviderRefreshSpec-HostGroup').first
    expect(child).to have_attributes(
      :type        => "ConfigurationProfileForeman",
      :name        => "ProviderRefreshSpec-ChildHostGroup",
      :description => "ProviderRefreshSpec-HostGroup/ProviderRefreshSpec-ChildHostGroup",
      :manager_ref => "14",
      :parent_id   => parent.id,
    )
    expect(child.operating_system_flavor).to     eq(mine(osfs))    # inherited from parent
    expect(child.customization_script_medium).to eq(mine(media))   # inherited from parent
    expect(child.customization_script_ptable).to eq(mine(ptables)) # declared
    expect(child.configuration_locations).to     eq([default_location])
    expect(child.configuration_organizations).to eq([default_organization])
  end

  def assert_configuration_profile_parent
    parent = configuration_manager.configuration_profiles.where(:name => 'ProviderRefreshSpec-HostGroup').first
    expect(parent).to have_attributes(
      :type        => "ConfigurationProfileForeman",
      :name        => "ProviderRefreshSpec-HostGroup",
      :description => "ProviderRefreshSpec-HostGroup",
      :manager_ref => "13",
    )
    expect(parent.operating_system_flavor).to     eq(mine(osfs))  # declared
    expect(parent.customization_script_medium).to eq(mine(media)) # declared
    expect(parent.customization_script_ptable).to be_nil          # blank
    expect(parent.configuration_locations).to     eq([default_location])
    expect(parent.configuration_organizations).to eq([default_organization])
  end

  def assert_configured_system
    child  = configuration_manager.configuration_profiles.where(:name => 'ProviderRefreshSpec-ChildHostGroup').first
    system = configuration_manager.configured_systems.where("hostname like 'providerrefreshspec%'").first

    expect(system).to have_attributes(
      :ipaddress   => "192.168.169.254",
      :mac_address => "00:00:00:00:00:00",
      :type        => "ConfiguredSystemForeman",
      :hostname    => "providerrefreshspec-hostbaremetal.example.com",
      :manager_ref => "38",
    )
    expect(system.operating_system_flavor).to     eq(mine(osfs))
    expect(system.customization_script_medium).to eq(mine(media))
    expect(system.customization_script_ptable).to eq(mine(ptables))
    expect(system.configuration_location).to      eq(default_location)
    expect(system.configuration_organization).to  eq(default_organization)
    expect(system.configuration_profile).to       eq(child)
  end

  private

  def mine(collection)
    collection.where(spec_related).first
  end
end
