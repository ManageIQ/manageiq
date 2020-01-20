RSpec.describe Rbac do
  before { allow(User).to receive_messages(:server_timezone => "UTC") }

  describe ".resources_shared_with" do
    let(:user) do
      FactoryBot.create(:user,
                         :role     => "user",
                         :tenant   => FactoryBot.create(:tenant, :name => "Tenant under root"),
                         :features => user_allowed_feature)
    end
    let(:user_allowed_feature) { "service" }
    let(:resource_to_be_shared) { FactoryBot.create(:vm_vmware, :tenant => user.current_tenant) }
    let(:tenants) { [sharee.current_tenant] }
    let(:features) { :all }
    let!(:share) do
      ResourceSharer.new(:user     => user,
                         :resource => resource_to_be_shared,
                         :tenants  => tenants,
                         :features => features)
    end
    let(:sharee) do
      FactoryBot.create(:user,
                         :miq_groups => [FactoryBot.create(:miq_group,
                                                            :tenant => FactoryBot.create(:tenant, :name => "Sibling tenant"))])
    end

    before { Tenant.seed }

    context "with direct tenant" do
      it "works" do
        expect(Rbac.resources_shared_with(sharee)).to be_empty

        share.share
        expect(Rbac.resources_shared_with(sharee)).to include(resource_to_be_shared)

        user.owned_shares.destroy_all
        expect(Rbac.resources_shared_with(sharee)).to be_empty
      end
    end

    context "with tenant inheritance" do
      let(:sibling_tenant) { FactoryBot.create(:tenant, :name => "Sibling tenant") }
      let(:siblings_child) { FactoryBot.create(:tenant, :parent => sibling_tenant, :name => "Sibling's child tenant") }
      let(:sharee) do
        FactoryBot.create(:user,
                           :miq_groups => [FactoryBot.create(:miq_group,
                                                              :tenant => siblings_child)])
      end
      let!(:share) do
        ResourceSharer.new(:user     => user,
                           :resource => resource_to_be_shared,
                           :tenants  => tenants,
                           :features => features,
                           :allow_tenant_inheritance => allow_tenant_inheritance)
      end
      let(:tenants) { [sibling_tenant] }

      context "enabled" do
        let(:allow_tenant_inheritance) { true }

        it "works" do
          expect(Rbac.resources_shared_with(sharee)).to be_empty

          share.share
          expect(Rbac.resources_shared_with(sharee)).to include(resource_to_be_shared)

          user.owned_shares.destroy_all
          expect(Rbac.resources_shared_with(sharee)).to be_empty
        end
      end

      context "disabled" do
        let(:allow_tenant_inheritance) { false }

        it "works" do
          expect(Rbac.resources_shared_with(sharee)).to be_empty

          share.share
          expect(Rbac.resources_shared_with(sharee)).to be_empty
        end
      end
    end
  end
end
