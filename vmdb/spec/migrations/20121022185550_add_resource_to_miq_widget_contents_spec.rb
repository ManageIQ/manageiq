require "spec_helper"
require Rails.root.join("db/migrate/20121022185550_add_resource_to_miq_widget_contents.rb")

describe AddResourceToMiqWidgetContents do
  migration_context :up do
    let(:user_stub)     { migration_stub(:User) }
    let(:content_stub)  { migration_stub(:MiqWidgetContent) }
    let(:group_stub)    { migration_stub(:MiqGroup) }
    let(:role_stub)     { migration_stub(:MiqUserRole) }

    it "normal user" do
      role    = role_stub.create!
      group   = group_stub.create!(:miq_user_role_id => role.id)
      user    = user_stub.create!(:miq_group => group)
      content = content_stub.create!(:user => user)

      migrate

      content = content_stub.find(content.id)
      content.owner_type.should == "MiqGroup"
      content.owner_id.should   == group.id
      content.timezone.should   == "UTC"
    end

    it "limited self service user" do
      role  = role_stub.create!(:settings => {:restrictions => {:vms => :user} } )
      group = group_stub.create!(:miq_user_role_id => role.id)
      user  = user_stub.create!(
        :miq_group => group,
        :settings => {:display => {:timezone => "Nuku'alofa" } }
      )
      content = content_stub.create!(:user => user)

      migrate

      content = content_stub.find(content.id)
      content.owner_type.should == "User"
      content.owner_id.should   == user.id
      content.timezone.should   == "Nuku'alofa"
    end

    it "self service user" do
      role    = role_stub.create!(:settings => {:restrictions => {:vms => :user_or_group } } )
      group   = group_stub.create!(:miq_user_role_id => role.id)
      user    = user_stub.create!(:miq_group => group)
      content = content_stub.create!(:user => user)

      migrate

      content = content_stub.find(content.id)
      content.owner_type.should == "User"
      content.owner_id.should   == user.id
    end
  end

  migration_context :down do
    let(:user_stub)     { migration_stub(:User) }
    let(:content_stub)  { migration_stub(:MiqWidgetContent) }
    let(:group_stub)    { migration_stub(:MiqGroup) }
    let(:role_stub)     { migration_stub(:MiqUserRole) }

    it "should restore user records" do
      owner   = user_stub.create!
      content = content_stub.create!(:owner_id => owner.id, :owner_type => 'User')

      migrate

      content.reload.user_id.should == owner.id
    end

    it "should delete group records" do
      content = content_stub.create!(:owner_id => 1, :owner_type => 'MiqGroup')

      migrate

      lambda {content.reload}.should raise_error ActiveRecord::RecordNotFound
    end
  end
end



