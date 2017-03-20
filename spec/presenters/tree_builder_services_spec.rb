describe TreeBuilderServices do
  let(:builder) { TreeBuilderServices.new("x", "y", {}) }

  it "generates tree" do
    create_deep_tree

    expect(root_nodes.size).to eq(2)
    active_nodes = kid_nodes(root_nodes[0])
    retired_nodes = kid_nodes(root_nodes[1])
    expect(active_nodes).to eq(
      @service => {
        @service_c1 => {
          @service_c11 => {},
          @service_c12 => {
            @service_c121 => {}
          }
        },
        @service_c2 => {}
      }
    )
    expect(retired_nodes).to eq(@service_c3 => {})
  end

  private

  def root_nodes
    builder.send(:x_get_tree_roots, false, {})
  end

  def kid_nodes(node)
    builder.send(:x_get_tree_custom_kids, node, false, {})
  end

  def create_deep_tree
    @service      = FactoryGirl.create(:service, :display => true, :retired => false)
    @service_c1   = FactoryGirl.create(:service, :service => @service, :display => true, :retired => false)
    @service_c11  = FactoryGirl.create(:service, :service => @service_c1, :display => true, :retired => false)
    @service_c12  = FactoryGirl.create(:service, :service => @service_c1, :display => true, :retired => false)
    @service_c121 = FactoryGirl.create(:service, :service => @service_c12, :display => true, :retired => false)
    @service_c2   = FactoryGirl.create(:service, :service => @service, :display => true, :retired => false)
    # hidden
    @service_c3   = FactoryGirl.create(:service, :service => @service, :retired => true)
  end
end
