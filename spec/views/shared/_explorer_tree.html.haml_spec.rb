describe "shared/_explorer_tree.html.haml" do
  let(:tree_1) { TreeBuilderConfigurationManager.new("tree_1", "tree_1", {}) }

  before do
    set_controller_for_view("provider_foreman")
    assign(:trees, [tree_1])
  end

  context "when showtype is 'details'" do
    it "should render shared explorer_tree view" do
      render :partial => "shared/explorer_tree", :locals => {:name => "tree_1"}
      expect(view).to render_template(:partial => 'shared/_explorer_tree')
    end
  end
end
