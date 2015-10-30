require "spec_helper"
require_migration

describe FixMiqGroupSequences do
  let(:group_stub) { migration_stub(:MiqGroup) }

  migration_context :up do
    it "assigns sequence" do
      g1 = group_stub.create
      g2 = group_stub.create(:sequence => 3)

      migrate

      expect(g1.reload.sequence).to be
      expect(g2.reload.sequence).to eq(3)
    end

    it "assigns guid" do
      old_guid = MiqUUID.new_guid
      g1 = group_stub.create
      g2 = group_stub.create(:guid => old_guid)

      migrate

      expect(g1.reload.guid).to be
      expect(g2.reload.guid).to eq(old_guid)
    end
  end
end
