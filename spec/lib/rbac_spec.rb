describe Rbac do
  before { allow(User).to receive_messages(:server_timezone => "UTC") }

  describe ".resources_shared_with" do
    let(:user) do
      FactoryGirl.create(:user,
                         :role     => "user",
                         :tenant   => FactoryGirl.create(:tenant, :name => "Tenant under root"),
                         :features => user_allowed_feature)
    end
    let(:user_allowed_feature) { "service" }
    let(:resource_to_be_shared) { FactoryGirl.create(:miq_template) }
    let(:tenants) { [sharee.current_tenant] }
    let(:features) { :all }
    let!(:share) do
      ResourceSharer.new(:user     => user,
                         :resource => resource_to_be_shared,
                         :tenants  => tenants,
                         :features => features)
    end
    let(:sharee) do
      FactoryGirl.create(:user,
                         :miq_groups => [FactoryGirl.create(:miq_group,
                                                            :tenant => FactoryGirl.create(:tenant, :name => "Sibling tenant"))])
    end

    before { Tenant.seed }

    it "works" do
      expect(Rbac.resources_shared_with(sharee)).to be_empty

      share.share

      expect(Rbac.resources_shared_with(sharee)).to include(resource_to_be_shared)
    end
  end
end
