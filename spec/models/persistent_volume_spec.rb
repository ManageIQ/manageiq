RSpec.describe PersistentVolume do
  it "has container volumes and pods" do
    pvc = FactoryBot.create(
      :persistent_volume_claim,
      :name => "test_claim"
    )

    group = FactoryBot.create(
      :container_group,
      :name => "group",
    )

    ems = FactoryBot.create(
      :ems_kubernetes,
      :id   => group.id,
      :name => "ems"
    )

    FactoryBot.create(
      :container_volume,
      :name                    => "container_volume",
      :type                    => 'ContainerVolume',
      :parent                  => group,
      :persistent_volume_claim => pvc
    )

    persistent_volume = FactoryBot.create(
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

  describe "#storage_capacity" do
    let(:storage_size) { 123_456_789 }

    it "returns value for :storage key in Hash column :capacity" do
      persistent_volume = FactoryBot.create(
        :persistent_volume,
        :capacity => {:storage => storage_size, :foo => "something"}
      )
      expect(persistent_volume.storage_capacity).to eq storage_size
    end

    it "returns nil if there is no :storage key in Hash column :capacity" do
      persistent_volume = FactoryBot.create(
        :persistent_volume,
        :capacity => {:foo => "something"}
      )
      expect(persistent_volume.storage_capacity).to be nil
    end
  end
end
