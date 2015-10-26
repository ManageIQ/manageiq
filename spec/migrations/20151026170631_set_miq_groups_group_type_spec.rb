require "spec_helper"
require_migration

describe SetMiqGroupsGroupType do
  let(:group_stub)  { migration_stub(:MiqGroup) }

  migration_context :up do
    it "sets nil groups" do
      g = group_stub.create

      migrate

      expect(g.reload.group_type).to eq("user")
    end

    it "doesnt set system groups" do
      g = group_stub.create(:group_type => "system")

      migrate

      expect(g.reload.group_type).to eq("system")
    end
  end

  migration_context :down do
  end
end
