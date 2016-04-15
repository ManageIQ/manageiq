describe MiqUserRole do
  before do
    @expected_user_role_count = 15
  end

  context ".seed" do
    it "empty table" do
      MiqUserRole.seed
      expect(MiqUserRole.count).to eq(@expected_user_role_count)
    end

    it "run twice" do
      MiqUserRole.seed
      MiqUserRole.seed
      expect(MiqUserRole.count).to eq(@expected_user_role_count)
    end

    it "with existing records" do
      changed   = FactoryGirl.create(:miq_user_role, :name => "EvmRole-administrator", :read_only => false)
      unchanged = FactoryGirl.create(:miq_user_role, :name => "xxx", :read_only => false)
      unchanged_orig_updated_at = unchanged.updated_at

      MiqUserRole.seed

      expect(MiqUserRole.count).to eq(@expected_user_role_count + 1)
      expect(changed.reload.read_only).to    be_truthy
      expect(unchanged.reload.updated_at).to be_same_time_as unchanged_orig_updated_at
    end

    it "fills up EvmRole-consumption_administrator role with 3 product features" do
      MiqProductFeature.seed
      MiqUserRole.seed

      consumption_role = MiqUserRole.find_by(:name => "EvmRole-consumption_administrator")
      expect(consumption_role).not_to be_nil
      features = consumption_role.miq_product_features.collect(&:identifier)

      expect(features).to match_array(%w(dashboard miq_report chargeback))
    end
  end

  context "testing allows methods" do
    before(:each) do
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

      feature1 = MiqProductFeature.find_all_by_identifier("dashboard_admin")
      @role1   = FactoryGirl.create(:miq_user_role, :name => "Role1", :miq_product_features => feature1)
      @group1  = FactoryGirl.create(:miq_group, :description => "Group1", :miq_user_role => @role1)
      @user1   = FactoryGirl.create(:user, :userid => "user1", :miq_groups => [@group1])

      feature2 = MiqProductFeature.find_all_by_identifier("everything")
      @role2   = FactoryGirl.create(:miq_user_role, :name => "Role2", :miq_product_features => feature2)
      @group2  = FactoryGirl.create(:miq_group, :description => "Group2", :miq_user_role => @role2)
      @user2   = FactoryGirl.create(:user, :userid => "user2", :miq_groups => [@group2])

      feature3 = MiqProductFeature.find_all_by_identifier(%w(host_show_list host_scan host_edit))
      @role3   = FactoryGirl.create(:miq_user_role, :name => "Role3", :miq_product_features => feature3)
      @group3  = FactoryGirl.create(:miq_group, :description => "Group3", :miq_user_role => @role3)
      @user3   = FactoryGirl.create(:user, :userid => "user3", :miq_groups => [@group3])
    end

    it "should return the correct answer calling allows? when requested feature is directly assigned or a descendant of a feature in a role" do
      expect(MiqUserRole.allows?(@role1.name, :identifier => "dashboard_admin")).to eq(true)
      expect(MiqUserRole.allows?(@role1.name, :identifier => "dashboard_add")).to eq(true)
      expect(MiqUserRole.allows?(@role1.name, :identifier => "dashboard_view")).to eq(false)
      expect(MiqUserRole.allows?(@role1.name, :identifier => "policy")).to eq(false)

      expect(MiqUserRole.allows?(@role2.name, :identifier => "dashboard_admin")).to eq(true)
      expect(MiqUserRole.allows?(@role2.name, :identifier => "dashboard_add")).to eq(true)
      expect(MiqUserRole.allows?(@role2.name, :identifier => "dashboard_view")).to eq(true)
      expect(MiqUserRole.allows?(@role2.name, :identifier => "policy")).to eq(true)

      # Test calling with an id of a role
      ident = MiqProductFeature.find_by_identifier("dashboard_admin")
      expect(MiqUserRole.allows?(@role1.id, :identifier => ident)).to eq(true)
    end

    it "should return the correct answer calling allows_any? with scope => :base)" do
      expect(MiqUserRole.allows_any?(@role1.name, :scope => :base, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"])).to eq(true)

      expect(MiqUserRole.allows_any?(@role2.name, :scope => :base, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"])).to eq(true)

      expect(MiqUserRole.allows_any?(@role3.name, :scope => :base, :identifiers => ["host_view"])).to eq(false)
      expect(MiqUserRole.allows_any?(@role3.name, :scope => :base, :identifiers => ["vm"])).to eq(false)
      expect(MiqUserRole.allows_any?(@role3.name, :scope => :base, :identifiers => ["everything"])).to eq(false)
    end

    it "should return the correct answer calling allows_any? with scope => :one)" do
      expect(MiqUserRole.allows_any?(@role1.name, :scope => :one, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"])).to eq(true)

      expect(MiqUserRole.allows_any?(@role2.name, :scope => :one, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"])).to eq(true)

      expect(MiqUserRole.allows_any?(@role3.name, :scope => :one, :identifiers => ["host_view"])).to eq(true)
      expect(MiqUserRole.allows_any?(@role3.name, :scope => :one, :identifiers => ["vm"])).to eq(false)
      expect(MiqUserRole.allows_any?(@role3.name, :scope => :one, :identifiers => ["everything"])).to eq(false)
    end

    it "should return the correct answer calling allows_any? with default scope => :sub" do
      expect(MiqUserRole.allows_any?(@role1.name, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"])).to eq(true)
      expect(MiqUserRole.allows_any?(@role2.name, :identifiers => ["dashboard_admin", "dashboard_add", "dashboard_view", "policy"])).to eq(true)
      expect(MiqUserRole.allows_any?(@role3.name, :identifiers => ["host_view"])).to eq(true)
      expect(MiqUserRole.allows_any?(@role3.name, :identifiers => ["vm"])).to eq(false)
      expect(MiqUserRole.allows_any?(@role3.name, :identifiers => ["everything"])).to eq(true)
    end

    it "should return the correct answer calling allows_any_children?" do
      expect(MiqUserRole.allows_any_children?(@role1.name, :identifier => "dashboard_admin")).to eq(true)
      expect(MiqUserRole.allows_any_children?(@role2.name, :identifier => "dashboard_admin")).to eq(true)
      expect(MiqUserRole.allows_any_children?(@role2.name, :identifier => "everything")).to eq(true)
      expect(MiqUserRole.allows_any_children?(@role1.name, :identifier => "everything")).to eq(true)
      expect(MiqUserRole.allows_any_children?(@role1.name, :identifier => "dashboard")).to eq(true)
    end
  end

  describe "#allow?" do
    it "allows everything" do
      EvmSpecHelper.seed_specific_product_features(%w(everything miq_report))
      user = FactoryGirl.create(:user, :features => "everything")
      expect(user).to be_role_allows(:identifier => "miq_report")
    end

    it "dissallows unentitled" do
      EvmSpecHelper.seed_specific_product_features(%w(miq_report container_dashboard))
      user = FactoryGirl.create(:user, :features => "container_dashboard")
      expect(user).not_to be_role_allows(:identifier => "miq_report")
    end

    it "allows entitled" do
      EvmSpecHelper.seed_specific_product_features(%w(miq_report))
      user = FactoryGirl.create(:user, :features => "miq_report")
      expect(user).to be_role_allows(:identifier => "miq_report")
    end

    # - container_dashboard
    # - miq_report_view
    #   - render_report_csv (H)

    it "disallows hidden child with not-entitled parent" do
      EvmSpecHelper.seed_specific_product_features(%w(miq_report_view render_report_csv container_dashboard))
      user = FactoryGirl.create(:user, :features => "container_dashboard")
      expect(user).not_to be_role_allows(:identifier => "render_report_csv")
    end

    it "allows hidden child with entitled parent" do
      EvmSpecHelper.seed_specific_product_features(%w(miq_report_view render_report_csv))
      user = FactoryGirl.create(:user, :features => "miq_report_view")
      expect(user).to be_role_allows(:identifier => "render_report_csv")
    end

    # - container_dashboard
    # - miq_report_widget_admin
    #   - widget_edit
    #   - widget_copy
    #   - widget_refresh (H)

    it "allows hidden child of not entitled, if a sibling is entitled" do
      EvmSpecHelper.seed_specific_product_features(
        %w(miq_report_widget_admin widget_refresh widget_edit widget_copy container_dashboard)
      )
      user = FactoryGirl.create(:user, :features => "widget_edit")
      expect(user).to be_role_allows(:identifier => "widget_refresh")
    end

    it "disallows hidden child of not entitled, if no sibling is entitled" do
      EvmSpecHelper.seed_specific_product_features(
        %w(miq_report_widget_admin widget_refresh widget_edit widget_copy container_dashboard)
      )
      user = FactoryGirl.create(:user, :features => "container_dashboard")
      expect(user).not_to be_role_allows(:identifier => "widget_refresh")
    end

    # - container_dashboard
    # - policy_profile_admin (H)
    #   - profile_new (H)
    it "allows hidden child of hidden parent" do
      EvmSpecHelper.seed_specific_product_features(
        %w(policy_profile_admin profile_new container_dashboard)
      )
      user = FactoryGirl.create(:user, :features => "container_dashboard")
      expect(user).to be_role_allows(:identifier => "profile_new")
    end
  end

  it "deletes with no group assigned" do
    role = FactoryGirl.create(:miq_user_role, :name => "test role")
    role.destroy
    expect(MiqUserRole.count).to eq(0)
  end

  it "does not delete with group assigned" do
    role = FactoryGirl.create(:miq_user_role, :name => "test role")
    FactoryGirl.create(:miq_group, :description => "test group", :miq_user_role => role)

    expect { role.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    expect(MiqUserRole.count).to eq(1)
  end

  # SUPER_ADMIN_ROLE_NAME = "EvmRole-super_administrator"
  # ADMIN_ROLE_NAME       = "EvmRole-administrator"

  describe "#super_admin_user?" do
    it "detects super admin" do
      expect(FactoryGirl.build(:miq_user_role, :role => "super_administrator")).to be_super_admin_user
    end

    it "detects admin" do
      expect(FactoryGirl.build(:miq_user_role, :role => "administrator")).not_to be_super_admin_user
    end

    it "detects non-admin" do
      expect(FactoryGirl.build(:miq_user_role)).not_to be_super_admin_user
    end
  end

  describe "#admin_user?" do
    it "detects super admin" do
      expect(FactoryGirl.build(:miq_user_role, :role => "super_administrator")).to be_admin_user
    end

    it "detects admin" do
      expect(FactoryGirl.build(:miq_user_role, :role => "administrator")).to be_admin_user
    end

    it "detects non-admin" do
      expect(FactoryGirl.build(:miq_user_role)).not_to be_admin_user
    end
  end

  describe "#destroy" do
    subject { miq_group.entitlement.miq_user_role }
    let!(:miq_group) { FactoryGirl.create(:miq_group, :role => "EvmRole-administrator") }

    context "when the role has any entitlements" do
      it "does not allow the role to be deleted" do
        expect { subject.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)
      end
    end

    context "with the entitlement removed" do
      before { miq_group.entitlement.destroy! }

      it "allows the role to be deleted" do
        expect { subject.destroy! }.not_to raise_error
      end
    end

    context "temporary backwards compatibility - groups destroy entitlements, allowing the role to be destroyed" do
      before { miq_group.destroy! }

      it "allows the role to be deleted" do
        expect { subject.destroy! }.not_to raise_error
      end
    end
  end
end
