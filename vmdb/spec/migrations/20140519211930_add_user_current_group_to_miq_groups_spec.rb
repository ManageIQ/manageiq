require "spec_helper"
require Rails.root.join("db/migrate/20140519211930_add_user_current_group_to_miq_groups.rb")

describe AddUserCurrentGroupToMiqGroups do
  migration_context :up do
    let(:miq_group_stub)  { migration_stub(:MiqGroup) }
    let(:user_stub)       { migration_stub(:User) }

    it "add current_group to miq_groups if miq_groups empty" do
      group = miq_group_stub.create!
      user  = user_stub.create!(:current_group => group)

      migrate

      expect(user.miq_groups).to match_array [group]
    end

    it "add current_group to miq_groups if miq_groups not empty" do
      group1 = miq_group_stub.create!
      group2 = miq_group_stub.create!
      user   = user_stub.create!(:current_group => group2, :miq_groups => [group1, group2])

      migrate

      expect(user.miq_groups).to match_array [group1, group2]
    end

    it "skip if current_group is present in miq_groups" do
      group = miq_group_stub.create!
      user  = user_stub.create!(:current_group => group, :miq_groups => [group])

      migrate

      expect(user.miq_groups).to match_array [group]
    end

    it "user's current_group is orphaned" do
      # model code was broken and could leave the current group orphaned
      group = miq_group_stub.create!
      user  = user_stub.create!(:current_group_id => (group.id + 1), :miq_groups => [group])

      migrate

      user.reload
      expect(user.miq_groups).to eq [group]
      expect(user.current_group).to be_nil
      expect(user.current_group_id).to be_nil
    end

    it "current group is valid but not in miq_groups" do
      group1 = miq_group_stub.create!
      group2 = miq_group_stub.create!
      user   = user_stub.create!(:current_group => group2, :miq_groups => [group1])

      migrate

      user.reload
      expect(user.miq_groups).to match_array [group1, group2]
      expect(user.current_group).to eql group2
    end

  end
end
