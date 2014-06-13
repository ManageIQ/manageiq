require "spec_helper"
require Rails.root.join("db/migrate/20140519211930_add_user_current_group_to_miq_groups.rb")

describe AddUserCurrentGroupToMiqGroups do
  migration_context :up do
    let(:miq_group_stub)  { migration_stub(:MiqGroup) }
    let(:user_stub)       { migration_stub(:User) }
    let(:join_table_stub) do
      Class.new(ActiveRecord::Base) do
        self.table_name  = "miq_groups_users"
        self.primary_key = nil
      end
    end

    it "add current_group to miq_groups if miq_groups empty" do
      group = miq_group_stub.create!
      user  = user_stub.create!(:current_group => group)

      migrate

      expect(user.miq_groups).to match_array [group]
    end

    it "add current_group to miq_groups if miq_groups not empty" do
      group1 = miq_group_stub.create!
      group2 = miq_group_stub.create!
      user   = user_stub.create!(:current_group => group2)
      join_table_stub.create!(:user_id => user.id, :miq_group_id => group1.id)

      migrate

      expect(user.miq_groups).to match_array [group1, group2]
    end

    it "skip if current_group is present in miq_groups" do
      group = miq_group_stub.create!
      user  = user_stub.create!(:current_group => group, :miq_groups => [group])

      migrate

      expect(user.miq_groups).to match_array [group]
    end
  end
end
