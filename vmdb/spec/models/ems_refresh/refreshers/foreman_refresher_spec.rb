require "spec_helper"

describe EmsRefresh::Refreshers::ForemanRefresher do
  let(:provider) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:provider_foreman,
                       :zone       => zone,
                       :url        => "10.8.96.102",
                       :verify_ssl => false,
                      )
  end

  it "will perform a full refresh on api v2" do
    VCR.use_cassette("#{described_class.name.underscore}_api_v2") do
      EmsRefresh.refresh(provider)
    end

    assert_table_counts
    assert_provisioning_manager
    assert_configuration_manager
  end

  def assert_table_counts
    expect(Provider.count).to                   eq(1)
    expect(CustomizationScript.count).to        eq(17)
    expect(CustomizationScriptPtable.count).to  eq(10)
    expect(CustomizationScriptMedium.count).to  eq(7)
    expect(OperatingSystemFlavor.count).to      eq(3)
    expect(ConfigurationProfile.count).to       eq(11)
    expect(ConfiguredSystem.count).to           eq(36)
  end

  def assert_provisioning_manager
    manager = Provider.first.provisioning_manager
    expect(manager).not_to be_nil

    css = manager.customization_scripts
    expect(css.count).to eq(17)
    expect(css.select { |cs| cs.class == CustomizationScriptPtable }.size).to  eq(10)
    expect(css.select { |cs| cs.class == CustomizationScriptMedium }.size).to  eq(7)
    expect(manager.operating_system_flavors.count).to     eq(3)
  end

  def assert_configuration_manager
    manager = Provider.first.configuration_manager
    expect(manager).not_to be_nil
    expect(manager.configured_systems.count).to  eq(36)
    expect(manager.configuration_profiles.count).to eq(11)

    # configured_system -> configuration_profile
    # configured_system -> operating_system_flavor
    # configured_system -> 2 customization_Scripts (1 medium, 1 ptable)
    # configured_system -> operating_system_flavor

    # configuration_profile -> operating_system_flavor
    # configuration_profile -> 2 customization_Scripts (1 medium, 1 ptable)
    # configuration_profile -> operating_system_flavor
  end

  def assert_specific_cluster
    # @cluster = EmsCluster.find_by_name("iSCSI")
    # @cluster.should have_attributes(
    #   :ems_ref                 => "/api/clusters/99408929-82cf-4dc7-a532-9d998063fa95",
    #   :ems_ref_obj             => "/api/clusters/99408929-82cf-4dc7-a532-9d998063fa95",
    #   :uid_ems                 => "99408929-82cf-4dc7-a532-9d998063fa95",
    #   :name                    => "iSCSI",
    #   :ha_enabled              => nil, # TODO: Should be true
    #   :ha_admit_control        => nil,
    #   :ha_max_failures         => nil,
    #   :drs_enabled             => nil, # TODO: Should be true
    #   :drs_automation_level    => nil,
    #   :drs_migration_threshold => nil
    # )

    # @cluster.all_resource_pools_with_default.size.should == 1
    # @default_rp = @cluster.default_resource_pool
    # @default_rp.should have_attributes(
    #   :ems_ref               => nil,
    #   :ems_ref_obj           => nil,
    #   :uid_ems               => "99408929-82cf-4dc7-a532-9d998063fa95_respool",
    #   :name                  => "Default for Cluster iSCSI",
    #   :memory_reserve        => nil,
    #   :memory_reserve_expand => nil,
    #   :memory_limit          => nil,
    #   :memory_shares         => nil,
    #   :memory_shares_level   => nil,
    #   :cpu_reserve           => nil,
    #   :cpu_reserve_expand    => nil,
    #   :cpu_limit             => nil,
    #   :cpu_shares            => nil,
    #   :cpu_shares_level      => nil,

    #   :is_default            => true
    # )
  end
end
