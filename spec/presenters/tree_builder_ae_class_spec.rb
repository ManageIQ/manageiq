require "spec_helper"
include AutomationSpecHelper

describe TreeBuilderAeClass do
  context "initialize" do
    before do
      user = FactoryGirl.create(:user_with_group)
      login_as user
      create_state_ae_model(:name => 'LUIGI', :ae_class => 'CLASS1', :ae_namespace => 'A/B/C')
      create_ae_model(:name => 'MARIO', :ae_class => 'CLASS3', :ae_namespace => 'C/D/E')
      @sb = {:trees => {:ot_tree => {:open_nodes => []}}, :active_tree => :ot_tree}
    end

    it "a tree with filter" do
      @sb[:cached_waypoint_ids] =  MiqAeClass.waypoint_ids_for_state_machines
      tree = TreeBuilderAeClass.new(:automate_tree, "automate", @sb)
      domains = JSON.parse(tree.tree_nodes).first['children'].collect { |h| h['title'] }
      expect(domains).to match_array ['LUIGI']
    end

    it "a tree without filter" do
      tree = TreeBuilderAeClass.new(:automate_tree, "automate", @sb)
      domains = JSON.parse(tree.tree_nodes).first['children'].collect { |h| h['title'] }
      expect(domains).to match_array %w(LUIGI MARIO)
    end
  end

  context "#x_get_tree_roots" do
    before do
      user = FactoryGirl.create(:user_with_group)
      login_as user
      tenant1 = user.current_tenant
      tenant2 = FactoryGirl.create(:tenant, :parent => tenant1)
      FactoryGirl.create(:miq_ae_domain, :name => "test1", :tenant => tenant1)
      FactoryGirl.create(:miq_ae_domain, :name => "test2", :tenant => tenant2)
    end

    it "should only return domains in a user's current tenant" do
      tree = TreeBuilderAeClass.new("ae_tree", "ae", {})
      domains = JSON.parse(tree.tree_nodes).first['children'].collect { |h| h['title'] }
      expect(domains).to match_array %w(test1)
      expect(domains).not_to include %w(test2)
    end
  end

  context "#x_get_tree_roots" do
    before do
      user = FactoryGirl.create(:user_with_group)
      login_as user
      tenant1 = user.current_tenant
      FactoryGirl.create(:miq_ae_domain, :name => "test1", :tenant => tenant1, :priority => 1)
      FactoryGirl.create(:miq_ae_domain, :name => "test2", :tenant => tenant1, :priority => 2)
    end

    it "should return domains in correct order" do
      tree = TreeBuilderAeClass.new("ae_tree", "ae", {})
      domains = JSON.parse(tree.tree_nodes).first['children'].collect { |h| h['title'] }
      expect(domains).to eq(%w(test2 test1))
    end
  end
end
