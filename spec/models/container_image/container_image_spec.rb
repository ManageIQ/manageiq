RSpec.describe ContainerImage do
  it "counts containers" do
    group = FactoryBot.create(
      :container_group,
      :name           => "group",
      :container_node => FactoryBot.create(:container_node, :name => "node")
    )
    expect(FactoryBot.create(
      :container_image,
      :containers => FactoryBot.create_list(:container, 2, :container_group => group)
    ).total_containers).to eq(2)
  end
end
