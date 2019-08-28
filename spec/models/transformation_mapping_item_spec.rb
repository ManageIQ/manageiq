RSpec.describe TransformationMappingItem, :v2v do
  let(:ems_vmware) { FactoryBot.create(:ems_vmware) }
  let(:vmware_cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => ems_vmware) }

  let(:ems_redhat) { FactoryBot.create(:ems_redhat) }
  let(:redhat_cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => ems_redhat) }

  let(:ems_openstack) { FactoryBot.create(:ems_openstack) }
  let(:openstack_cluster) { FactoryBot.create(:ems_cluster_openstack, :ext_management_system => ems_openstack) }

  context "source cluster validation" do
    let(:valid_mapping_item) do
      FactoryBot.build(:transformation_mapping_item, :source => vmware_cluster, :destination => openstack_cluster)
    end

    let(:invalid_mapping_item) do
      FactoryBot.build(:transformation_mapping_item, :source => openstack_cluster, :destination => openstack_cluster)
    end

    it "passes validation if the source cluster is not a supported type" do
      expect(valid_mapping_item.valid?).to be true
    end

    it "fails validation if the source cluster is not a supported type" do
      expect(invalid_mapping_item.valid?).to be false
      expect(invalid_mapping_item.errors[:source].first).to match("EMS type of source cluster must be in")
    end
  end

  context "destination cluster validation" do
    let(:valid_mapping_item) do
      FactoryBot.build(:transformation_mapping_item, :source => vmware_cluster, :destination => redhat_cluster)
    end

    let(:invalid_mapping_item) do
      FactoryBot.build(:transformation_mapping_item, :source => vmware_cluster, :destination => vmware_cluster)
    end

    it "passes validation if the source cluster is not a supported type" do
      expect(valid_mapping_item.valid?).to be true
    end

    it "fails validation if the source cluster is not a supported type" do
      expect(invalid_mapping_item.valid?).to be false
      expect(invalid_mapping_item.errors[:destination].first).to match("EMS type of destination cluster or cloud tenant must be in")
    end
  end

  context "datastore validation" do
    let(:ems_vmware) { FactoryBot.create(:ems_vmware) }
    let(:vmware_cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => ems_vmware) }

    let(:ems_redhat) { FactoryBot.create(:ems_redhat) }
    let(:redhat_cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => ems_redhat) }

    let(:ems_ops) { FactoryBot.create(:ems_openstack) }
    let(:cloud_tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems_ops) }

    context "source vmware datastore" do
      let(:src_vmware_host) { FactoryBot.create(:host_vmware, :ems_cluster => vmware_cluster) }
      let(:src_storage) { FactoryBot.create(:storage_vmware, :hosts => [src_vmware_host]) }

      context "destination openstack" do
        let(:disk) { FactoryBot.create(:disk) }
        let(:cloud_volume_openstack) { FactoryBot.create(:cloud_volume_openstack, :attachments => [disk], :cloud_tenant => cloud_tenant) }

        let(:tmi_ops_cluster) { FactoryBot.create(:transformation_mapping_item, :source => vmware_cluster, :destination => cloud_tenant) }
        let(:ops_mapping) { FactoryBot.create(:transformation_mapping, :transformation_mapping_items => [tmi_ops_cluster]) }

        let(:valid_source) { FactoryBot.create(:transformation_mapping_item, :source => src_storage, :destination => cloud_volume_openstack, :transformation_mapping_id => ops_mapping.id) }
        let(:invalid_source) { FactoryBot.build(:transformation_mapping_item, :source => cloud_volume_openstack, :destination => src_storage, :transformation_mapping_id => ops_mapping.id) }

        it "valid source" do
          expect(valid_source.valid?).to be(true)
        end
        it "invalid source" do
          expect(invalid_source.valid?).to be(false)
        end
      end

      context "destination red hat" do
        let(:dst_redhat_host) { FactoryBot.create(:host_redhat, :ems_cluster => redhat_cluster) }
        let(:dst_storage) { FactoryBot.create(:storage_nfs, :hosts => [dst_redhat_host]) }

        let(:tmi_cluster) { FactoryBot.create(:transformation_mapping_item, :source => vmware_cluster, :destination => redhat_cluster) }

        let(:rh_mapping) { FactoryBot.create(:transformation_mapping, :transformation_mapping_items => [tmi_cluster]) }

        context "source validation" do
          let(:valid_storage) { FactoryBot.create(:transformation_mapping_item, :source => src_storage, :destination => dst_storage, :transformation_mapping_id => rh_mapping.id) }
          let(:invalid_storage) { FactoryBot.build(:transformation_mapping_item, :source => dst_storage, :destination => src_storage, :transformation_mapping_id => rh_mapping.id) }

          it "validate rhev destination" do
            expect(valid_storage.valid?).to be(true)
          end
          it "invalidate badrhev destination" do
            expect(invalid_storage.valid?).to be(false)
          end
        end
      end
    end
  end
end
