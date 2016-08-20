describe ContainerNode do
  it "has distinct images" do
    group = FactoryGirl.create(
      :container_group,
      :name => "group",
    )
    FactoryGirl.create(
      :container_image,
      :containers => [FactoryGirl.create(:container, :name => "container_a", :container_group => group),
                      FactoryGirl.create(:container, :name => "container_b", :container_group => group)]
    )
    expect(group.container_images.count).to eq(1)
  end
end
