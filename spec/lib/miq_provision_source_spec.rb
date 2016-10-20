describe MiqProvisionSource do
  context "get_provisioning_request_source_class" do
    it "returns CloudVolumeSnapshot" do
      kls = described_class.get_provisioning_request_source_class("CloudVolumeSnapshot")
      expect(kls).to eq(CloudVolumeSnapshot)
    end

    it "returns CloudVolume" do
      kls = described_class.get_provisioning_request_source_class("CloudVolume")
      expect(kls).to eq(CloudVolume)
    end

    it "defaults to VmOrTemplate for unknown values" do
      kls = described_class.get_provisioning_request_source_class("some_class")
      expect(kls).to eq(VmOrTemplate)
      kls = described_class.get_provisioning_request_source_class(nil)
      expect(kls).to eq(VmOrTemplate)
    end
  end

  context "get_provisioning_request_source" do
    it "returns a CloudVolume when given the right id and src type" do
      cloud_volume = FactoryGirl.create(:cloud_volume_openstack)

      src = described_class.get_provisioning_request_source(cloud_volume.id, "CloudVolume")
      expect(src).to eq(cloud_volume)
    end

    it "returns a CloudVolumeSnapshot when given the right id and src type" do
      cloud_volume_snapshot = FactoryGirl.create(:cloud_volume_snapshot_openstack)

      src = described_class.get_provisioning_request_source(cloud_volume_snapshot.id, "CloudVolumeSnapshot")
      expect(src).to eq(cloud_volume_snapshot)
    end

    it "returns a VmOrTemplate when given the right id and any other src value" do
      vm_or_template = FactoryGirl.create(:vm_openstack)

      src = described_class.get_provisioning_request_source(vm_or_template.id, nil)
      expect(src).to eq(vm_or_template)
    end

    it "returns nil when given an invalid id" do
      FactoryGirl.create(:cloud_volume_openstack)

      src = described_class.get_provisioning_request_source("invalid_id", "CloudVolume")
      expect(src).to eq(nil)
    end
  end
end
