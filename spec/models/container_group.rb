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
      :name                    => "persistent_volume",
      :parent                  => ems,
      :persistent_volume_claim => pvc
    )

    assert_pod_to_pv_relationships(group)
  end

  def assert_pod_to_pv_relationships(group)
    expect(group.persistent_volume_claim.first.name).to eq("test_claim")
    expect(group.persistent_volume_claim.count).to eq(1)
    expect(group.persistent_volumes.first.name).to eq("persistent_volume")
    expect(group.persistent_volumes.count).to eq(1)
  end
end
