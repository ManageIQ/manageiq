require "spec_helper"
require_migration

describe AssignTenantDefaultGroup do
  let(:tenant_stub) { migration_stub(:Tenant) }
  let(:group_stub)  { migration_stub(:MiqGroup) }
  let(:role_stub)   { migration_stub(:MiqUserRole) }
  let(:tenant_role) { role_stub.create!(:name => role_stub::DEFAULT_TENANT_ROLE_NAME) }

  migration_context :up do
    context "role exists" do
      before do
        tenant_role # make sure it exists
      end

      it "creates a group (and assigns the role)" do
        t = tenant_stub.create!
        expect(t.default_miq_group_id).not_to be

        migrate

        t.reload
        expect(t.default_miq_group_id).to be
        g = group_stub.find(t.default_miq_group_id)
        expect(g.miq_user_role_id).to eq(tenant_role.id)
        expect(g.sequence).to be
      end

      it "skips tenants that already have a group" do
        g = group_stub.create!(:description => "custom group")
        t = tenant_stub.create!
        t.update_attributes(:default_miq_group_id => g.id)

        migrate

        expect(t.reload.default_miq_group_id).to eq(g.id)
      end
    end

    it "creates a group (even though group role is not defined yet)" do
      t = tenant_stub.create!
      migrate

      t.reload
      expect(t.default_miq_group_id).to be
      expect(group_stub.find(t.default_miq_group_id).miq_user_role_id).to be_nil
    end
  end
end
