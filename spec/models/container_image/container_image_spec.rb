describe ContainerImage do
  it "counts containers" do
    group = FactoryGirl.create(
      :container_group,
      :name           => "group",
      :container_node => FactoryGirl.create(:container_node, :name => "node")
    )
    expect(FactoryGirl.create(
      :container_image,
      :containers => FactoryGirl.create_list(:container, 2, :container_group => group)
    ).total_containers).to eq(2)
  end
end
