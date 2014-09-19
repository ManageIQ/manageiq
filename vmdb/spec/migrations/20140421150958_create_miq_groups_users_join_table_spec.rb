require "spec_helper"
require Rails.root.join("db/migrate/20140421150958_create_miq_groups_users_join_table.rb")

describe CreateMiqGroupsUsersJoinTable do
  migration_context :up do
    let(:user_stub)       { migration_stub(:User) }
    let(:join_table_stub) { migration_stub(:MiqGroupsUsers) }
    let(:reserve_stub)    { MigrationSpecStubs.reserved_stub }

    it "migrates eligible_miq_group_ids from reserved column" do
      user = user_stub.create!
      reserve_stub.create!(:resource_type => "User",
                           :resource_id   => user.id,
                           :reserved      => {:eligible_miq_group_ids => [101, 108, 111]}
      )
      reserve_stub.count.should eq(1)

      migrate

      expect(reserve_stub.count).to eq(0)
      expect(join_table_stub.where(:user_id => user.id).pluck(:miq_group_id)).to match_array [101, 108, 111]
    end

    it "ignores users with no eligible_miq_group_ids" do
      user = user_stub.create!(:userid => "test")

      migrate

      join_table_stub.where(:user_id => user.id).count.should == 0
    end
  end
end
