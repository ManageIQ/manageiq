describe PersistentVolume do
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

    persistent_volume = FactoryGirl.create(
      :persistent_volume,
      :name                    => "persistent_volume",
      :parent                  => ems,
      :persistent_volume_claim => pvc
    )

    assert_pv_relationships(persistent_volume)
  end

  def assert_pv_relationships(persistent_volume)
    expect(persistent_volume.container_volumes.first.name).to eq("container_volume")
    expect(persistent_volume.container_volumes.count).to eq(1)
    expect(persistent_volume.container_groups.first.name).to eq("group")
    expect(persistent_volume.container_groups.count).to eq(1)
  end
end
