require_migration

describe RemoveMiqUserRoleFromMiqGroups do
  let(:miq_group_stub)   { migration_stub(:MiqGroup) }
  let(:entitlement_stub) { migration_stub(:Entitlement) }
  let!(:miq_group)       { miq_group_stub.create!(:entitlement => entitlement_stub.create!(:miq_user_role_id => 25)) }

  migration_context :down do
    it "sets the miq_user_role_id back on miq_groups" do
      migrate
      expect(miq_group.reload.miq_user_role_id).to eq 25
    end
  end
end
