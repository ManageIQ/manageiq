describe TreeBuilderOpsRbac do
  describe ".new" do
    before { MiqRegion.seed }

    def assert_tree_nodes(expected)
      tree_json  = TreeBuilderOpsRbac.new("rbac_tree", "rbac", {}).tree_nodes
      tree_nodes = JSON.parse(tree_json).first['children'].collect { |h| h['title'] }
      expect(tree_nodes).to match_array expected
    end

    it "with user with rbac_group role" do
      login_as FactoryGirl.create(:user, :features => 'rbac_group_view')
      assert_tree_nodes(["Groups"])
    end

    it "with user with rbac_role_view role" do
      login_as FactoryGirl.create(:user, :features => 'rbac_role_view')
      assert_tree_nodes(["Roles"])
    end

    it "with user with rbac_tenant role" do
      login_as FactoryGirl.create(:user, :features => 'rbac_tenant_view')
      assert_tree_nodes(["Tenants"])
    end

    it "with user with rbac_user role" do
      login_as FactoryGirl.create(:user, :features => 'rbac_user_view')
      assert_tree_nodes(["Users"])
    end

    it "with user with multiple rbac roles" do
      login_as FactoryGirl.create(:user,
        :features => %w(rbac_group_view rbac_user_view rbac_role_view rbac_tenant_view)
      )
      assert_tree_nodes(%w(Groups Users Roles Tenants))
    end
  end
end
