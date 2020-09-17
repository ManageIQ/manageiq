RSpec.describe TransformationMappingItem, :v2v do
  let(:ems_vmware) { FactoryBot.create(:ems_vmware) }
  let(:vmware_cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => ems_vmware) }

  let(:ems_redhat) { FactoryBot.create(:ems_redhat) }
  let(:redhat_cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => ems_redhat) }

  let(:ems_openstack) { FactoryBot.create(:ems_openstack) }
  let(:openstack_cluster) { FactoryBot.create(:ems_cluster_openstack, :ext_management_system => ems_openstack) }

  it "doesn't access database when unchanged model is saved" do
    m = FactoryBot.create(:transformation_mapping_item)
    expect { m.valid? }.not_to make_database_queries
  end

  # ---------------------------------------------------------------------------
  # Cluster Validation
  # ---------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------
  # Datastore Validation
  # ---------------------------------------------------------------------------
  context "datastore validation" do
    let(:cloud_tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems_openstack) }

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

  # ---------------------------------------------------------------------------
  # Network Validation
  # ---------------------------------------------------------------------------
  context "Network validation" do
    let(:dst_cloud_tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems_openstack) }
    let(:other_cloud_tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems_openstack) }
    let(:shared_cloud_network) { FactoryBot.create(:cloud_network_private_openstack, :cloud_tenant => other_cloud_tenant, :shared => true) }

    before do
      ems_openstack.network_manager.private_networks << shared_cloud_network
    end

    # source network
    context "source vmware network" do
      let(:src_vmware_host) { FactoryBot.create(:host_vmware, :ems_cluster => vmware_cluster) }
      let(:src_switch) { FactoryBot.create(:switch, :hosts => [src_vmware_host]) }
      let(:src_lan) { FactoryBot.create(:lan, :switch => src_switch) }

      context "destination openstack" do
        let(:dst_cloud_network) { FactoryBot.create(:cloud_network_openstack, :cloud_tenant => dst_cloud_tenant) }

        let(:tmi_osp_cluster) { FactoryBot.create(:transformation_mapping_item, :source => vmware_cluster, :destination => dst_cloud_tenant) }
        let(:osp_mapping) { FactoryBot.create(:transformation_mapping, :transformation_mapping_items => [tmi_osp_cluster]) }


        it "valid mapping with private network" do
          tmi = FactoryBot.create(:transformation_mapping_item, :source => src_lan, :destination => dst_cloud_network, :transformation_mapping_id => osp_mapping.id)
          expect(tmi.valid?).to be(true)
        end
        it "valid mapping with shared network" do
          tmi = FactoryBot.create(:transformation_mapping_item, :source => src_lan, :destination => shared_cloud_network, :transformation_mapping_id => osp_mapping.id)
          expect(tmi.valid?).to be(true)
        end
        it "invalid source" do
          tmi = FactoryBot.build(:transformation_mapping_item, :source => dst_cloud_network, :destination => src_lan, :transformation_mapping_id => osp_mapping.id)
          expect(tmi.valid?).to be(false)
        end
      end

      context "destination red hat" do
        let(:dst_rh_host) { FactoryBot.create(:host_redhat, :ems_cluster => redhat_cluster) }
        let(:dst_rh_switch) { FactoryBot.create(:switch, :hosts => [dst_rh_host]) }
        let(:dst_rh_lan) { FactoryBot.create(:lan, :switch=> dst_rh_switch) }

        let(:tmi_cluster) { FactoryBot.create(:transformation_mapping_item, :source => vmware_cluster, :destination => redhat_cluster) }

        let(:rh_mapping) { FactoryBot.create(:transformation_mapping, :transformation_mapping_items => [tmi_cluster]) }

        context "source validation" do
          let(:valid_lan) { FactoryBot.create(:transformation_mapping_item, :source => src_lan, :destination => dst_rh_lan, :transformation_mapping_id => rh_mapping.id) }
          let(:invalid_lan) { FactoryBot.build(:transformation_mapping_item, :source => dst_rh_lan, :destination => src_lan, :transformation_mapping_id => rh_mapping.id) }

          it "valid rhev lan" do
            expect(valid_lan.valid?).to be(true)
          end
          it "invalid rhev lan" do
            expect(invalid_lan.valid?).to be(false)
          end
        end
      end
    end
  end
end
