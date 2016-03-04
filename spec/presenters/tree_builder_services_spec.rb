describe TreeBuilderServices do
  let(:builder) { TreeBuilderServices.new("x", "y", {}) }

  it "generates tree" do
    create_deep_tree

    expect(root_nodes).to eq([@service])
    expect(kid_nodes(@service)).to match_array([@service_c1, @service_c2])
    expect(kid_nodes(@service_c1)).to match_array([@service_c11, @service_c12])
    expect(kid_nodes(@service_c12)).to match_array([@service_c121])
    expect(kid_nodes(@service_c11)).to be_blank
    expect(kid_nodes(@service_c121)).to be_blank
    expect(kid_nodes(@service_c2)).to be_blank
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
    @service_c1   = FactoryGirl.create(:service, :service => @service, :display => true)
    @service_c11  = FactoryGirl.create(:service, :service => @service_c1, :display => true)
    @service_c12  = FactoryGirl.create(:service, :service => @service_c1, :display => true)
    @service_c121 = FactoryGirl.create(:service, :service => @service_c12, :display => true)
    @service_c2   = FactoryGirl.create(:service, :service => @service, :display => true)
    # hidden
    @service_c3   = FactoryGirl.create(:service, :service => @service, :display => false)
  end
end
