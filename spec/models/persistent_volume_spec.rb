RSpec.describe PersistentVolume do
  let(:pvc) { FactoryBot.create(:persistent_volume_claim) }
  let(:group) { FactoryBot.create(:container_group) }
  let(:ems) { FactoryBot.create(:ems_kubernetes, :name => 'ems_name') }
  let(:volume) do
    FactoryBot.create(
      :container_volume,
      :type                    => 'ContainerVolume',
      :parent                  => group,
      :persistent_volume_claim => pvc
    )
  end

  it "has container volumes and pods" do
    persistent_volume = FactoryBot.create(
      :persistent_volume,
      :parent                  => ems,
      :persistent_volume_claim => pvc
    )

    expect(persistent_volume.container_volumes).to eq([volume])
    expect(persistent_volume.container_groups).to eq([group])
  end

  describe "#parent_name" do
    it "matches group_name" do
      persistent_volume = FactoryBot.create(
        :persistent_volume,
        :parent                  => ems,
        :persistent_volume_claim => pvc
      )
      expect(persistent_volume.parent_name).to eq(ems.name)
    end
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

  describe "#parent_name" do
    subject do
      FactoryBot.create(
        :persistent_volume,
        :parent                  => ems,
        :persistent_volume_claim => pvc
      )
    end

    # delegating through a polymorphic forces us to ruby only
    it_behaves_like "ruby only virtual_attribute", :parent_name, 'ems_name'
  end
end
