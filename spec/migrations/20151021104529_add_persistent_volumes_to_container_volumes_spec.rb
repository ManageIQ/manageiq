require "spec_helper"
require_migration

describe AddPersistentVolumesToContainerVolumes do
  let(:container_volume_stub) { migration_stub(:ContainerVolume) }

  migration_context :up do
    it "up" do
      container_volume = container_volume_stub.create!

      migrate

      expect(container_volume.reload).to have_attributes(:parent_type => "ContainerGroup")
    end
  end

  migration_context :down do
    it "down" do
      container_volume = container_volume_stub.create!(:parent_type => "ContainerGroup")
      persistent_volume = container_volume_stub.create!(:parent_type => "ManageIQ::Providers::Kubernetes::ContainerManager")

      migrate

      expect(ContainerVolume.find(container_volume.id)).not_to respond_to(:parent_type)
      expect(ContainerVolume.exists?(persistent_volume.id)).to be false
    end
  end
end
