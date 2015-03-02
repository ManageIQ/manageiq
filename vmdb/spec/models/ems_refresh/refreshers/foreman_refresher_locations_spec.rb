require "spec_helper"

describe EmsRefresh::Refreshers::ForemanRefresher do
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
  let(:configuration_manager) { provider.configuration_manager }

  it "loads data with locations and organizations" do
    EmsRefresh.stub(:queue_refresh) { |*args| EmsRefresh.refresh(*args) }

    VCR.use_cassette("#{described_class.name.underscore}_api_locations_v2") do
      EmsRefresh.refresh(provisioning_manager)
      expect(provisioning_manager.reload.last_refresh_error).to be_nil
      EmsRefresh.refresh(configuration_manager)
      expect(configuration_manager.reload.last_refresh_error).to be_nil
    end

    orgs = provisioning_manager.configuration_organizations.where(spec_related)
    locs = provisioning_manager.configuration_locations.where(spec_related)

    expect(orgs.size).to eq(2)
    expect(locs.size).to eq(2)

    child  = configuration_manager.configuration_profiles.where(:name => 'ProviderRefreshSpec-ChildHostGroup').first
    expect(child.configuration_organizations.sort_by(&:id)).to eq(orgs.sort_by(&:id))
    expect(child.configuration_locations.sort_by(&:id)).to     eq(locs.sort_by(&:id))

    system = configuration_manager.configured_systems.where("hostname like 'providerrefreshspec%'").first
    expect(system.configuration_organization).to eq(orgs.select { |h| h.name =~ /Child/ }.first)
    expect(system.configuration_location).to     eq(locs.select { |h| h.name =~ /Child/ }.first)
  end

  private

  def mine(collection)
    collection.where(spec_related).first
  end
end
