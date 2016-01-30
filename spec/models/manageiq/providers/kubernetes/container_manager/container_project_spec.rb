describe ContainerProject do
  it "has distinct nodes" do
    node = FactoryGirl.create(:container_node, :name => "n")
    expect(FactoryGirl.create(
    :container_project,
    :container_groups => [FactoryGirl.create(:container_group, :name => "g1", :container_node => node),
                          FactoryGirl.create(:container_group, :name => "g2", :container_node => node)]
    ).container_nodes.count).to eq(1)
  end
end
