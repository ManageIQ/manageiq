require_migration

describe SetMiqGroupsGroupType do
  let(:group_stub)  { migration_stub(:MiqGroup) }

  migration_context :up do
    it "sets groups with no type to user" do
      g = group_stub.create

      migrate

      expect(g.reload.group_type).to eq("user")
    end

    it "does not change system groups" do
      g = group_stub.create(:group_type => "system")

      migrate

      expect(g.reload.group_type).to eq("system")
    end
  end

  migration_context :down do
    it "clears groups with user type" do
      g = group_stub.create(:group_type => "user")

      migrate

      expect(g.reload.group_type).to be_nil
    end

    it "does not change system groups" do
      g = group_stub.create(:group_type => "system")

      migrate

      expect(g.reload.group_type).to eq("system")
    end
  end
end
