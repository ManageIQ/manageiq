RSpec.describe TransformationMappingItem, :v2v do
  let(:vmware_cluster) { FactoryBot.create(:ems_cluster, :vmware_ems) }
  let(:redhat_cluster) { FactoryBot.create(:ems_cluster, :redhat_ems) }
  let(:openstack_cluster) { FactoryBot.create(:ems_cluster_openstack, :openstack_ems) }

   context "source cluster validation" do
    let(:valid_mapping_item) {
      FactoryBot.build(:transformation_mapping_item, :source => vmware_cluster, :destination => openstack_cluster)
    }

     let(:invalid_mapping_item) {
      FactoryBot.build(:transformation_mapping_item, :source => openstack_cluster, :destination => openstack_cluster)
    }

     it "passes validation if the source cluster is not a supported type" do
      expect(valid_mapping_item.valid?).to be true
    end

     it "fails validation if the source cluster is not a supported type" do
      expect(invalid_mapping_item.valid?).to be false
      expect(invalid_mapping_item.errors[:source].first).to match("EMS type of source cluster must be in")
    end
  end

  context "destination cluster validation" do
    let(:valid_mapping_item) {
      FactoryBot.build(:transformation_mapping_item, :source => vmware_cluster, :destination => redhat_cluster)
    }

    let(:invalid_mapping_item) {
      FactoryBot.build(:transformation_mapping_item, :source => vmware_cluster, :destination => vmware_cluster)
    }

    it "passes validation if the source cluster is not a supported type" do
      expect(valid_mapping_item.valid?).to be true
    end

    it "fails validation if the source cluster is not a supported type" do
      expect(invalid_mapping_item.valid?).to be false
      expect(invalid_mapping_item.errors[:destination].first).to match("EMS type of destination cluster or cloud tenant must be in")
    end
  end
end
