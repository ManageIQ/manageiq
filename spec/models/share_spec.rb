describe Share do
  before { allow(User).to receive(:server_timezone).and_return("UTC") }

  it "is invalidated when the sharer loses features" do
    EvmSpecHelper.seed_specific_product_features(%w(host service))
    user = FactoryGirl.create(:user, :role => "user", :features => "service")
    resource_to_be_shared = FactoryGirl.create(:miq_template)
    features = [MiqProductFeature.find_by(:identifier => "service")]
    share = create_share(user, resource_to_be_shared, features)

    replace_user_features(user, "host")

    expect { share.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end

  def create_share(user, resource, features)
    tenant = FactoryGirl.create(:tenant)
    ResourceSharer.new(
      :user => user,
      :resource => resource,
      :tenants => [tenant],
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
