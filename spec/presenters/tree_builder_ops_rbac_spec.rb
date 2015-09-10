require "spec_helper"

describe TreeBuilderOpsRbac do
  context "initialize" do
    before do
      [MiqRegion, MiqProductFeature, MiqUserRole].each(&:seed)
    end

    it "Super Admin role should see all nodes in Access Control tree" do
      create_user_with_role('EvmRole-super_administrator')
      tree = TreeBuilderOpsRbac.new("rbac_tree", "rbac", {})
      tree_nodes = JSON.parse(tree.tree_nodes).first['children'].collect { |h| h['title'] }
      tree_nodes.should match_array %w(Groups Users Roles Tenants)
    end

    it "Tenant Admin role should only see Tenants nodes in Access Control tree" do
      create_user_with_role('EvmRole-tenant_administrator')
      tree = TreeBuilderOpsRbac.new("rbac_tree", "rbac", {})
      tree_nodes = JSON.parse(tree.tree_nodes).first['children'].collect { |h| h['title'] }
      tree_nodes.should match_array %w(Tenants)
      tree_nodes.should_not match_array %w(Groups Users Roles)
    end
  end
end

def create_user_with_role(role_name)
  role = MiqUserRole.find_by_name(role_name)
  group = FactoryGirl.create(:miq_group, :miq_user_role => role)
  login_as FactoryGirl.create(:user, :userid => 'wilma', :miq_groups => [group])
end
