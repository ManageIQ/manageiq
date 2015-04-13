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
  let(:configuration_manager) { provider.configuration_manager }
  let(:orgs) { provisioning_manager.configuration_organizations.where(spec_related).sort_by(&:name) }
  let(:locs) { provisioning_manager.configuration_locations.where(spec_related).sort_by(&:name) }

  it "loads data with locations and organizations" do
    EmsRefresh.stub(:queue_refresh) { |*args| EmsRefresh.refresh(*args) }

    2.times do
      VCR.use_cassette("#{described_class.name.underscore}_api_locations_v2") do
        EmsRefresh.refresh(provisioning_manager)
        expect(configuration_manager.reload.last_refresh_error).to be_nil
        expect(provisioning_manager.reload.last_refresh_error).to be_nil
      end
    end

    test_orgs
    test_locs
    test_child
    test_system
  end

  def test_child
    child  = configuration_manager.configuration_profiles.where(:name => 'ProviderRefreshSpec-ChildHostGroup').first
    expect(child.configuration_organizations).to match_array(orgs)
    expect(child.configuration_locations).to     match_array(locs)
  end

  def test_system
    system = configuration_manager.configured_systems.where("hostname like 'providerrefreshspec%'").first
    expect(system.configuration_organization).to eq(orgs.select { |h| h.name =~ /Child/ }.first)
    expect(system.configuration_location).to     eq(locs.select { |h| h.name =~ /Child/ }.first)
  end

  def test_orgs
    expect(orgs.size).to eq(2)
    child = orgs.first
    parent = orgs.last
    expect(child).to have_attributes(
      :title     => "Infra/ProviderRefreshSpecOrganization/ProviderRefreshSpecChildOrganization",
      :name      => "ProviderRefreshSpecChildOrganization",
      :parent_id => parent.id,
    )
    expect(parent).to have_attributes(
      :title => "Infra/ProviderRefreshSpecOrganization",
      :name  => "ProviderRefreshSpecOrganization",
    )
  end

  def test_locs
    expect(locs.size).to eq(2)
    child = locs.first
    parent = locs.last
    expect(child).to have_attributes(
      :title     => "ProviderRefreshSpec-Location/ProviderRefreshSpec-ChildLocation",
      :name      => "ProviderRefreshSpec-ChildLocation",
      :parent_id => parent.id,
    )
    expect(parent).to have_attributes(
      :title => "ProviderRefreshSpec-Location",
      :name  => "ProviderRefreshSpec-Location",
    )
  end

  private

  def mine(collection)
    collection.where(spec_related).first
  end
end
