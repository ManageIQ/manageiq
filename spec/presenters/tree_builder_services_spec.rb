describe TreeBuilderServices do
  let(:builder) { TreeBuilderServices.new("x", "y", {}) }

  it "generates tree" do
    create_deep_tree

    expect(root_nodes).to eq(
      @service => {},
      @service_c1 => {},
      @service_c2 => {},
      @service_c3 => {}
      )
  end

  private

  def root_nodes
    builder.send(:x_get_tree_roots, false, {})
  end

  def kid_nodes(node)
    builder.send(:x_get_tree_service_kids, node, false)
  end

  def create_deep_tree
    @service      = FactoryGirl.create(:service, :display => true)
    @service_c1   = FactoryGirl.create(:service, :display => true)
    @service_c11  = FactoryGirl.create(:service, :service => @service_c1, :display => true)
    @service_c12  = FactoryGirl.create(:service, :service => @service_c1, :display => true)
    @service_c121 = FactoryGirl.create(:service, :service => @service_c12, :display => true)
    @service_c2   = FactoryGirl.create(:service, :display => true)
    @service_c3   = FactoryGirl.create(:service, :display => false)
  end
end
