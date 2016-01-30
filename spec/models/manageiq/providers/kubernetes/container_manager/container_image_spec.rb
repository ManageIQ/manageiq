describe ContainerImage do
  it "has distinct nodes" do
    group = FactoryGirl.create(
      :container_group,
      :name => "group",
      :container_node => FactoryGirl.create(:container_node, :name => "node")
    )
    expect(FactoryGirl.create(
      :container_image,
      :containers => [FactoryGirl.create(:container, :name => "container_a", :container_group => group),
                      FactoryGirl.create(:container, :name => "container_b", :container_group => group)]
    ).container_nodes.count).to eq(1)
    end
end

