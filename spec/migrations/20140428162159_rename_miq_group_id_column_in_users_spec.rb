require "spec_helper"
require Rails.root.join("db/migrate/20140428162159_rename_miq_group_id_column_in_users.rb")

describe RenameMiqGroupIdColumnInUsers do
  migration_context :up do
    let(:miq_group_stub) { migration_stub(:MiqGroup) }
    let(:user_stub)      { migration_stub(:User) }

    it "renames miq_group_id to current_group_id" do
      miq_group = miq_group_stub.create!
      user      = user_stub.create!(:miq_group_id => miq_group.id)
      user_id   = user.id

      migrate

      user_stub.find(user_id).current_group_id.should eq miq_group.id
    end
  end
end
