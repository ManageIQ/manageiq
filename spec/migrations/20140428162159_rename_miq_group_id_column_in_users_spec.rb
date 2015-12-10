require "spec_helper"
require_migration

describe RenameMiqGroupIdColumnInUsers do
  migration_context :up do
    let(:miq_group_stub) { migration_stub(:MiqGroup) }
    let(:user_stub)      { migration_stub(:User) }

    it "renames miq_group_id to current_group_id" do
      miq_group = miq_group_stub.create!
      user      = user_stub.create!(:miq_group_id => miq_group.id)
      user_id   = user.id

      migrate

      expect(user_stub.find(user_id).current_group_id).to eq miq_group.id
    end
  end
end
