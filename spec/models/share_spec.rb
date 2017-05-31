describe Share do
  before { allow(User).to receive(:server_timezone).and_return("UTC") }

  it "is invalidated when the sharer is no longer has the features that were shared" do
    EvmSpecHelper.seed_specific_product_features(%w(host service))
    user = FactoryGirl.create(:user, :role => "user", :features => "service")
    resource_to_be_shared = FactoryGirl.create(:miq_template)
    features = [MiqProductFeature.find_by(:identifier => "service")]
    share = create_share(user, resource_to_be_shared, features)

    replace_user_features(user, "host")

    expect { share.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "does something" do
    EvmSpecHelper.seed_specific_product_features(%w(host))

    tenant = FactoryGirl.create(:tenant)
    group = FactoryGirl.create(:miq_group, :role => "user", :features => "host", :tenant => tenant)

    other_tenant = FactoryGirl.create(:tenant)
    other_group = FactoryGirl.create(:miq_group, :role => "otheruser", :features => "host", :tenant => other_tenant)

    user = FactoryGirl.create(:user, :miq_groups => [group])

    resource_to_be_shared = FactoryGirl.create(:miq_template, :tenant => tenant)
    features = [MiqProductFeature.find_by(:identifier => "host")]
    share = create_share(user, resource_to_be_shared, features)

    expect(Rbac::Filterer.filtered_object(resource_to_be_shared, :user => user)).to be_present

    user.miq_groups = [other_group]

    expect(Rbac::Filterer.filtered_object(resource_to_be_shared, :user => user)).not_to be_present

    expect { share.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end

  def create_share(user, resource, features)
    tenant = FactoryGirl.create(:tenant)
    ResourceSharer.new(
      :user     => user,
      :resource => resource,
      :tenants  => [tenant],
      :features => features
    ).share
    tenant.shares.first
  end

  def replace_user_features(user, *identifiers)
    user.miq_user_role.miq_product_features = []
    identifiers.each do |identifier|
      user.miq_user_role.miq_product_features << MiqProductFeature.find_by(:identifier => identifier)
    end
  end
end
