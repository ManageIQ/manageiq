describe CloudVolume do
  it ".available" do
    disk = FactoryGirl.create(:disk)
    cv1 = FactoryGirl.create(:cloud_volume, :attachments => [disk])
    cv2 = FactoryGirl.create(:cloud_volume)

    expect(described_class.available).to eq([cv2])
  end

  context ".class_by_ems" do
    let(:openstack_cloud) { FactoryGirl.create(:ems_openstack) }
    let(:cinder) { FactoryGirl.create(:ems_cinder, :parent_ems_id => openstack_cloud.id) }
    let(:amazon_cloud) { FactoryGirl.create(:ems_amazon) }
    let(:ebs) { FactoryGirl.create(:ems_amazon_ebs, :parent_ems_id => amazon_cloud.id) }
    let(:block_ems) { FactoryGirl.create(:ems_cinder) }

    it "OpenStack cloud manager should return it's CloudVolume type" do
      expect(CloudVolume.class_by_ems(openstack_cloud)).to eq(ManageIQ::Providers::Openstack::CloudManager::CloudVolume)
    end

    it "Cinder block storage manager should return CloudVolume type of the parent manager" do
      expect(CloudVolume.class_by_ems(cinder)).to eq(ManageIQ::Providers::Openstack::CloudManager::CloudVolume)
    end

    it "Amazon cloud manager should return base CloudVolume type" do
      expect(CloudVolume.class_by_ems(amazon_cloud)).to eq(CloudVolume)
    end

    it "Amazon block storage manager should return it's CloudVolume type" do
      expect(CloudVolume.class_by_ems(ebs)).to eq(ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume)
    end

    it "should return nil when no ems is provided" do
      expect(CloudVolume.class_by_ems(nil)).to eq(nil)
    end

    it "should return CloudVolume when parent manager is nil" do
      expect(CloudVolume.class_by_ems(block_ems)).to eq(CloudVolume)
    end
  end
end
