describe TreeBuilderContainers do
  let(:tag)   { FactoryGirl.create(:tag, :name => "/managed/department/accounting") }
  let(:role)  { FactoryGirl.create(:miq_user_role, :name => "EvmRole-operator") }
  let(:group) { FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Group 1") }
  let(:user)  { FactoryGirl.create(:user, :userid => 'User 1', :miq_groups => [group]) }

  before do
    MiqRegion.seed
    EvmSpecHelper.local_miq_server

    @tagged_container = FactoryGirl.create(:container, :name => "Tagged Container", :tags => [tag])
    @untagged_container = FactoryGirl.create(:container, :name => "Untagged Container")

    login_as user
  end

  describe ".new" do
    def get_tree_results(tree)
      JSON.parse(tree.tree_nodes).first['children'].collect { |h| h['title'] }
    end

    it "returns all containers" do
      tree = TreeBuilderContainers.new("containers_tree", "containers", {}, true)
      results = get_tree_results(tree)
      expect(results).to match_array(["Untagged Container", "Tagged Container"])
    end

    it "returns tagged containers, logged user with tag filter" do
      user.current_group.entitlement = Entitlement.create!
      user.current_group.entitlement.set_managed_filters([tag.name])
      @tree = TreeBuilderContainers.new("containers_tree", "containers", {}, true)
      results = get_tree_results(@tree)
      expect(results).to match_array(["Tagged Container"])
    end
  end
end
