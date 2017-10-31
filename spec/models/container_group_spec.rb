describe ContainerGroup do
  it "has container volumes and pods" do
    pvc = FactoryGirl.create(
      :persistent_volume_claim,
      :name => "test_claim"
    )

    group = FactoryGirl.create(
      :container_group,
      :name => "group",
    )

    ems = FactoryGirl.create(
      :ems_kubernetes,
      :id   => group.id,
      :name => "ems"
    )

    FactoryGirl.create(
      :container_volume,
      :name                    => "container_volume",
      :type                    => 'ContainerVolume',
      :parent                  => group,
      :persistent_volume_claim => pvc
    )

    FactoryGirl.create(
      :persistent_volume,
      :name                    => "persistent_volume0",
      :parent                  => ems,
      :persistent_volume_claim => pvc
    )

    FactoryGirl.create(
      :persistent_volume,
      :name                    => "persistent_volume1",
      :parent                  => ems,
      :persistent_volume_claim => pvc
    )

    assert_pod_to_pv_relationships(group)
  end

  def assert_pod_to_pv_relationships(group)
    expect(group.persistent_volume_claim.first.name).to eq("test_claim")
    expect(group.persistent_volume_claim.count).to eq(1)
    expect(group.persistent_volumes.first.name).to eq("persistent_volume0")
    expect(group.persistent_volumes.second.name).to eq("persistent_volume1")
    expect(group.persistent_volumes.count).to eq(2)
  end

  describe "#generic_custom_buttons" do
    before do
      allow(CustomButton).to receive(:buttons_for).with("ContainerGroup").and_return("this is a list of custom buttons")
    end

    it "returns all the custom buttons for container groups" do
      expect(ContainerGroup.new.generic_custom_buttons).to eq("this is a list of custom buttons")
    end
  end
end
