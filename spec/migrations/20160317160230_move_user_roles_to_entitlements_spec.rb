require_migration

describe MoveUserRolesToEntitlements do
  let(:miq_group_stub) { migration_stub(:MiqGroup) }
  let(:entitlement_stub) { migration_stub(:Entitlement) }
  let!(:miq_group1) { miq_group_stub.create!(:miq_user_role_id => 25) }
  let!(:miq_group2) { miq_group_stub.create!(:miq_user_role_id => 50) }

  migration_context :up do
    it "creates an entitlement for each miq_group with the miq_group_id and the group's miq_user_role" do
      expect(entitlement_stub.count).to eq(0)

      migrate

      expect(entitlement_stub.exists?(:miq_group_id => miq_group1.id, :miq_user_role_id => 25)).to be_truthy
      expect(entitlement_stub.exists?(:miq_group_id => miq_group2.id, :miq_user_role_id => 50)).to be_truthy
      expect(entitlement_stub.count).to eq(2)
    end
  end
end
