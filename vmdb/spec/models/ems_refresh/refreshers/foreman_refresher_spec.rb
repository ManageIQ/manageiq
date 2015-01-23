require "spec_helper"

describe EmsRefresh::Refreshers::ForemanRefresher do
  # where clause to use spec related entries
  let(:spec_related) { "name like 'ProviderRefreshSpec%'" }
  let(:provider) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    FactoryGirl.create(:provider_foreman,
                       :zone       => zone,
                       :url        => "10.8.96.102",
                       :verify_ssl => false,
                      )
  end

  # these values are from the
  let(:provisioning_manager) { Provider.first.provisioning_manager }
  let(:osfs) { provisioning_manager.operating_system_flavors }
  let(:customization_scripts) { provisioning_manager.customization_scripts }
  let(:media) { customization_scripts.where(:type => "CustomizationScriptMedium") }
  let(:ptables) { customization_scripts.where(:type => "CustomizationScriptPtable") }

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
    expect(CustomizationScript.count).to        eq(19)
    expect(CustomizationScriptPtable.count).to  eq(11)
    expect(CustomizationScriptMedium.count).to  eq(8)
    expect(OperatingSystemFlavor.count).to      eq(5)
    expect(ConfigurationProfile.count).to       eq(14)
    expect(ConfiguredSystem.count).to           eq(39)
  end

  def assert_provisioning_manager
    expect(provisioning_manager).not_to    be_nil
    expect(customization_scripts.count).to eq(19)
    expect(ptables.count).to               eq(11)
    expect(media.count).to                 eq(8)
    expect(osfs.count).to                  eq(5)

    medium = mine(media)
    ptable = mine(ptables)
    osf = mine(osfs)

    expect(medium.attributes).to include(
      "name"        => "ProviderRefreshSpec-Media",
      "type"        => "CustomizationScriptMedium",
      "manager_ref" => "8"
    )
    expect(ptable.attributes).to include(
      "name"        => "ProviderRefreshSpec-PartitionTable",
      "type"        => "CustomizationScriptPtable",
      "manager_ref" => "12"
    )

    expect(osf.attributes).to include(
      "name"        => "ProviderRefreshSpec-OperatingSystem 1.2",
      "description" => "OS 1.2",
      "manager_ref" => "4"
    )
    expect(osf.customization_scripts).to include(ptable)
    expect(osf.customization_scripts).to include(medium)
  end

  def assert_configuration_manager
    manager = Provider.first.configuration_manager
    expect(manager).not_to be_nil
    expect(manager.configured_systems.count).to  eq(39)
    expect(manager.configuration_profiles.count).to eq(14)

    child  = manager.configuration_profiles.where(:name => 'ProviderRefreshSpec-ChildHostGroup').first
    parent = manager.configuration_profiles.where(:name => 'ProviderRefreshSpec-HostGroup').first
    system = manager.configured_systems.where("hostname like 'providerrefreshspec%'").first

    medium = mine(media)
    ptable = mine(ptables)
    osf = mine(osfs)



    expect(child.attributes).to include(
      "type"        => "ConfigurationProfileForeman",
      "name"        => "ProviderRefreshSpec-ChildHostGroup",
      "description" => "ProviderRefreshSpec-HostGroup/ProviderRefreshSpec-ChildHostGroup",
      "manager_ref" => "14",
    )
    expect(child.operating_system_flavor).to     eq(osf)    # inherited from parent
    expect(child.customization_script_medium).to eq(medium)   # inherit
    expect(child.customization_script_ptable).to eq(ptable) # declared

    expect(parent.attributes).to include(
      "type"        => "ConfigurationProfileForeman",
      "name"        => "ProviderRefreshSpec-HostGroup",
      "description" => "ProviderRefreshSpec-HostGroup",
      "manager_ref" => "13",
    )
    expect(parent.operating_system_flavor).to     eq(osf)  # declared
    expect(parent.customization_script_medium).to eq(medium) # declared
    expect(parent.customization_script_ptable).to be_nil          # blank

    expect(system.attributes).to include(
      "type"        => "ConfiguredSystemForeman",
      "hostname"    => "providerrefreshspec-hostbaremetal.cloudforms.lab.eng.rdu2.redhat.com",
      "manager_ref" => "38",
    )
    expect(system.operating_system_flavor).to eq(osf)
    expect(system.configuration_profile).to   eq(child)
  end

  private

  def mine(collection)
    collection.where(spec_related).first
  end
end
