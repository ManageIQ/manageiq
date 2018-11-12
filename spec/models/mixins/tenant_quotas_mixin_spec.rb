describe TenantQuotasMixin do
  before do
    Tenant.seed
  end

  let(:root_tenant) do
    Tenant.root_tenant
  end

  let(:super_admin_role)  { FactoryGirl.create(:miq_user_role, :features => MiqProductFeature::SUPER_ADMIN_FEATURE) }
  let(:tenant_admin_role) { FactoryGirl.create(:miq_user_role, :features => MiqProductFeature::TENANT_ADMIN_FEATURE) }

  let(:tenant_1)   { FactoryGirl.create(:tenant, :parent => root_tenant) }
  let(:tenant_1_1) { FactoryGirl.create(:tenant, :parent => tenant_1) }
  let(:tenant_1_2) { FactoryGirl.create(:tenant, :parent => tenant_1, :divisible => false) }

  let(:group_tenant_1_tenant_admin) { FactoryGirl.create(:miq_group, :miq_user_role => tenant_admin_role, :tenant => tenant_1) }
  let(:user_tenant_1_tenant_admin)  { FactoryGirl.create(:user, :miq_groups => [group_tenant_1_tenant_admin]) }

  let(:group_tenant_1_super_admin) { FactoryGirl.create(:miq_group, :miq_user_role => super_admin_role, :tenant => tenant_1) }
  let(:user_tenant_1_super_admin)  { FactoryGirl.create(:user, :miq_groups => [group_tenant_1_super_admin]) }

  describe "#tenant_quotas_allowed?" do
    it "allows managing on all tenant quotas when user is super admin" do
      User.with_user(user_tenant_1_super_admin) do
        expect(root_tenant.tenant_quotas_allowed?).to be_truthy
        expect(tenant_1.tenant_quotas_allowed?).to be_truthy
        expect(tenant_1_1.tenant_quotas_allowed?).to be_truthy
        expect(tenant_1_2.tenant_quotas_allowed?).to be_truthy
      end
    end

    context "user has tenant-admin role" do
      it "allows managing on tenant quotas" do
        User.with_user(user_tenant_1_tenant_admin) do
          expect(root_tenant.tenant_quotas_allowed?).to be_falsey
          expect(tenant_1.tenant_quotas_allowed?).to be_falsey
          expect(tenant_1_1.tenant_quotas_allowed?).to be_truthy
          expect(tenant_1_2.tenant_quotas_allowed?).to be_truthy
        end
      end
    end
  end
end
