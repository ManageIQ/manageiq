require "spec_helper"

describe MiqUserRole do
  context ".seed" do
    it "empty table" do
      MiqRegion.seed
      MiqUserRole.seed
      MiqUserRole.count.should == 12
    end

    it "run twice" do
      MiqRegion.seed
      MiqUserRole.seed
      MiqUserRole.seed
      MiqUserRole.count.should == 12
    end

    it "with existing records" do
      changed   = FactoryGirl.create(:miq_user_role, :name => "EvmRole-administrator", :read_only => false)
      unchanged = FactoryGirl.create(:miq_user_role, :name => "xxx", :read_only => false)
      unchanged_orig_updated_at = unchanged.updated_at

      MiqRegion.seed
      MiqUserRole.seed

      MiqUserRole.count.should == 13
      changed.reload.read_only.should    be_true
      unchanged.reload.updated_at.should be_same_time_as unchanged_orig_updated_at
    end
  end

  context "testing allows methods" do
    before(:each) do
      MiqRegion.seed

      EvmSpecHelper.seed_specific_product_features(%w(
        dashboard_add
        dashboard_view
        host_compare
        host_edit
        host_scan
        host_show_list
        policy
        vm
      ))

      @idents1 = ["dashboard_admin"]
      @role1   = FactoryGirl.create(:miq_user_role, :name => "Role1", :miq_product_features => MiqProductFeature.find_all_by_identifier(@idents1))
      @group1  = FactoryGirl.create(:miq_group, :description => "Group1", :miq_user_role => @role1)
      @user1   = FactoryGirl.create(:user, :userid => "user1", :miq_groups => [@group1])

      @idents2 = ["everything"]
      @role2   = FactoryGirl.create(:miq_user_role, :name => "Role2", :miq_product_features => MiqProductFeature.find_all_by_identifier(@idents2))
      @group2  = FactoryGirl.create(:miq_group, :description => "Group2", :miq_user_role => @role2)
      @user2   = FactoryGirl.create(:user, :userid => "user2", :miq_groups => [@group2])

      @idents3 = ["host_show_list", "host_scan", "host_edit"]
      @role3   = FactoryGirl.create(:miq_user_role, :name => "Role3", :miq_product_features => MiqProductFeature.find_all_by_identifier(@idents3))
      @group3  = FactoryGirl.create(:miq_group, :description => "Group3", :miq_user_role => @role3)
      @user3   = FactoryGirl.create(:user, :userid => "user3", :miq_groups => [@group3])
    end

    it "should return the correct answer calling allows? when requested feature is directly assigned or a descendant of a feature in a role" do
      MiqUserRole.allows?(@role1.name, :identifier => "dashboard_admin").should  == true
      MiqUserRole.allows?(@role1.name, :identifier => "dashboard_add").should == true
      MiqUserRole.allows?(@role1.name, :identifier => "dashboard_view").should   == false
      MiqUserRole.allows?(@role1.name, :identifier => "policy").should           == false

      MiqUserRole.allows?(@role2.name, :identifier => "dashboard_admin").should  == true
      MiqUserRole.allows?(@role2.name, :identifier => "dashboard_add").should == true
      MiqUserRole.allows?(@role2.name, :identifier => "dashboard_view").should   == true
      MiqUserRole.allows?(@role2.name, :identifier => "policy").should           == true

      # Test calling with an id of a role
      ident = MiqProductFeature.find_by_identifier("dashboard_admin")
      MiqUserRole.allows?(@role1.id, :identifier => ident).should  == true
    end

    it "should return the correct answer calling allows_*? with scope => :base)" do
      MiqUserRole.allows_any?(@role1.name, :scope => :base, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"]).should  == true
      MiqUserRole.allows_all?(@role1.name, :scope => :base, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"]).should  == false

      MiqUserRole.allows_any?(@role2.name, :scope => :base, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"]).should  == true
      MiqUserRole.allows_all?(@role2.name, :scope => :base, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"]).should  == true

      MiqUserRole.allows_all?(@role3.name, :scope => :base, :identifiers => ["host_show_list", "host_scan", "host_edit"]).should  == true
      MiqUserRole.allows_all?(@role3.name, :scope => :base, :identifiers => ["host_view"]).should  == false
      MiqUserRole.allows_any?(@role3.name, :scope => :base, :identifiers => ["host_view"]).should  == false
      MiqUserRole.allows_any?(@role3.name, :scope => :base, :identifiers => ["vm"]).should  == false
      MiqUserRole.allows_all?(@role3.name, :scope => :base, :identifiers => ["vm"]).should  == false
      MiqUserRole.allows_any?(@role3.name, :scope => :base, :identifiers => ["everything"]).should  == false
    end

    it "should return the correct answer calling allows_*? with scope => :one)" do
      MiqUserRole.allows_any?(@role1.name, :scope => :one, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"]).should  == true
      MiqUserRole.allows_all?(@role1.name, :scope => :one, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"]).should  == false

      MiqUserRole.allows_any?(@role2.name, :scope => :one, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"]).should  == true
      MiqUserRole.allows_all?(@role2.name, :scope => :one, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"]).should  == false

      MiqUserRole.allows_all?(@role3.name, :scope => :one, :identifiers => ["host_show_list", "host_scan", "host_edit"]).should  == false
      MiqUserRole.allows_all?(@role3.name, :scope => :one, :identifiers => ["host_view"]).should  == false
      MiqUserRole.allows_any?(@role3.name, :scope => :one, :identifiers => ["host_view"]).should  == true
      MiqUserRole.allows_any?(@role3.name, :scope => :one, :identifiers => ["vm"]).should  == false
      MiqUserRole.allows_all?(@role3.name, :scope => :one, :identifiers => ["vm"]).should  == false
      MiqUserRole.allows_any?(@role3.name, :scope => :one, :identifiers => ["everything"]).should  == false
    end

    it "should return the correct answer calling allows_*? with default scope => :sub" do
      MiqUserRole.allows_any?(@role1.name, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"]).should  == true
      MiqUserRole.allows_all?(@role1.name, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"]).should  == false

      MiqUserRole.allows_any?(@role2.name, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"]).should  == true
      MiqUserRole.allows_all?(@role2.name, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"]).should  == true

      MiqUserRole.allows_all?(@role3.name, :identifiers => ["host_show_list", "host_scan", "host_edit"]).should  == true
      MiqUserRole.allows_all?(@role3.name, :identifiers => ["host_view"]).should  == false
      MiqUserRole.allows_any?(@role3.name, :identifiers => ["host_view"]).should  == true
      MiqUserRole.allows_any?(@role3.name, :identifiers => ["vm"]).should  == false
      MiqUserRole.allows_all?(@role3.name, :identifiers => ["vm"]).should  == false
      MiqUserRole.allows_any?(@role3.name, :identifiers => ["everything"]).should  == true
    end

    it "should return the correct answer calling allows_*_children?" do
      MiqUserRole.allows_any_children?(@role1.name, :identifier => "dashboard_admin").should  == true
      MiqUserRole.allows_all_children?(@role1.name, :identifier => "dashboard_admin").should  == true

      MiqUserRole.allows_any_children?(@role2.name, :identifier => "dashboard_admin").should  == true
      MiqUserRole.allows_all_children?(@role2.name, :identifier => "dashboard_admin").should  == true

      MiqUserRole.allows_any_children?(@role2.name, :identifier => "everything").should  == true
      MiqUserRole.allows_all_children?(@role2.name, :identifier => "everything").should  == true

      MiqUserRole.allows_any_children?(@role1.name, :identifier => "everything").should  == true
      MiqUserRole.allows_all_children?(@role1.name, :identifier => "everything").should  == false

      MiqUserRole.allows_any_children?(@role1.name, :identifier => "dashboard").should  == true
      MiqUserRole.allows_all_children?(@role1.name, :identifier => "dashboard").should  == false
    end
  end

  it "should not be deleted while a group is still assigned" do
    role = FactoryGirl.create(:miq_user_role, :name => "test role")
    FactoryGirl.create(:miq_group, :description => "test group", :miq_user_role => role)

    expect { role.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    MiqUserRole.count.should eq 1
  end
end
