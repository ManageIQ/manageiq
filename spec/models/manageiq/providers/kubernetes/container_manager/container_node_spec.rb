describe ContainerNode do
  it "has distinct routes" do
    service = FactoryGirl.create(
    :container_service,
    :name => "s",
    :container_routes => [FactoryGirl.create(:container_route, :name => "rt")]
    )
    expect(FactoryGirl.create(
    :container_node,
    :name => "n",
    :container_groups => [FactoryGirl.create(:container_group, :name => "g1", :container_services => [service]),
                          FactoryGirl.create(:container_group, :name => "g2", :container_services => [service])]
    ).container_routes.count).to eq(1)
  end

  it "has distinct images" do
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
    expect(node.container_images.count).to eq(1)
  end
end
