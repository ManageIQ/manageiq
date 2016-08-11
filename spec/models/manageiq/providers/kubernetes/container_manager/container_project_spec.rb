describe ContainerProject do
  it "has distinct nodes" do
    node = FactoryGirl.create(:container_node, :name => "n")
    expect(FactoryGirl.create(
    :container_project,
    :container_groups => [FactoryGirl.create(:container_group, :name => "g1", :container_node => node),
                          FactoryGirl.create(:container_group, :name => "g2", :container_node => node)]
    ).container_nodes.count).to eq(1)
  end

  it "has distinct images" do
    # Create a project with 2 containers from different pods that run the same image
    node = FactoryGirl.create(:container_node, :name => "n")
    group = FactoryGirl.create(
      :container_group,
      :name           => "group",
      :container_node => node
    )
    group2 = FactoryGirl.create(
      :container_group,
      :name           => "group2",
      :container_node => node
    )
    FactoryGirl.create(
      :container_image,
      :containers => [FactoryGirl.create(:container, :name => "container_a", :container_group => group),
                      FactoryGirl.create(:container, :name => "container_b", :container_group => group2)]
    )
    expect(FactoryGirl.create(:container_project, :container_groups => [group]).container_images.count).to eq(1)
  end
end
