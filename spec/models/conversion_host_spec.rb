describe ConversionHost do
  let(:apst) { FactoryGirl.create(:service_template_ansible_playbook) }

  context "provider independent methods" do
    let(:host) { FactoryGirl.create(:host) }
    let(:vm) { FactoryGirl.create(:vm_or_template) }
    let(:conversion_host_1) { FactoryGirl.create(:conversion_host, :resource => host) }
    let(:conversion_host_2) { FactoryGirl.create(:conversion_host, :resource => vm) }
    let(:task_1) { FactoryGirl.create(:service_template_transformation_plan_task, :state => 'active', :conversion_host => conversion_host_1) }
    let(:task_2) { FactoryGirl.create(:service_template_transformation_plan_task, :conversion_host => conversion_host_1) }
    let(:task_3) { FactoryGirl.create(:service_template_transformation_plan_task, :state => 'active', :conversion_host => conversion_host_2) }

    before do
      conversion_host_1.concurrent_transformation_limit = "2"
      conversion_host_2.concurrent_transformation_limit = "1"

      allow(ServiceTemplateTransformationPlanTask).to receive(:where).with(:state => 'active').and_return([task_1, task_3])
    end

    it "#active_tasks" do
      expect(conversion_host_1.active_tasks).to eq([task_1])
      expect(conversion_host_2.active_tasks).to eq([task_3])
    end

    it "#eligible?" do
      expect(conversion_host_1.eligible?).to eq(true)
      expect(conversion_host_2.eligible?).to eq(false)
    end

    context "#source_transport_method" do
      it { expect(conversion_host_2.source_transport_method).to be_nil }

      context "ssh transport enabled" do
        before { conversion_host_2.ssh_transport_supported = true }
        it { expect(conversion_host_2.source_transport_method).to eq('ssh') }

        context "vddk transport enabled" do
          before { conversion_host_2.vddk_transport_supported = true }
          it { expect(conversion_host_2.source_transport_method).to eq('vddk') }
        end
      end
    end
  end

  context "source is vmwarews" do
    let(:src_ems) { FactoryGirl.create(:ems_vmware, :zone => FactoryGirl.create(:zone)) }
    let(:src_cluster) { FactoryGirl.create(:ems_cluster, :ext_management_system => src_ems) }
    let(:src_host) { FactoryGirl.create(:host, :ext_management_system => src_ems, :ipaddress => '10.0.0.1') }
    let(:src_storage) { FactoryGirl.create(:storage, :ext_management_system => src_ems) }

    let(:src_lan_1) { FactoryGirl.create(:lan) }
    let(:src_lan_2) { FactoryGirl.create(:lan) }
    let(:src_nic_1) { FactoryGirl.create(:guest_device_nic, :lan => src_lan_1) }
    let(:src_nic_2) { FactoryGirl.create(:guest_device_nic, :lan => src_lan_2) }

    let(:src_disk_1) { instance_double("disk", :device_name => "Hard disk 1", :device_type => "disk", :filename => "[datastore12] test_vm/test_vm.vmdk", :size => 17_179_869_184) }
    let(:src_disk_2) { instance_double("disk", :device_name => "Hard disk 2", :device_type => "disk", :filename => "[datastore12] test_vm/test_vm-2.vmdk", :size => 17_179_869_184) }

    let(:src_hardware) { FactoryGirl.create(:hardware, :nics => [src_nic_1, src_nic_2]) }

    let(:src_vm) { FactoryGirl.create(:vm_vmware, :ext_management_system => src_ems, :ems_cluster => src_cluster, :host => src_host, :hardware => src_hardware) }

    let(:source_disks) do
      [
        {:path => src_disk_1.filename, :size => src_disk_1.size, :percent => 0, :weight  => 50.0 },
        {:path => src_disk_2.filename, :size => src_disk_2.size, :percent => 0, :weight  => 50.0 }
      ]
    end

    before do
      allow(src_hardware).to receive(:disks).and_return([src_disk_1, src_disk_2])
      allow(src_disk_1).to receive(:storage).and_return(src_storage)
      allow(src_host).to receive(:fingerprint).and_return('01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67')
      allow(src_host).to receive(:authentication_userid).and_return('esx_user')
      allow(src_host).to receive(:authentication_password).and_return('esx_passwd')
    end

    context "destination is rhevm" do
      let(:dst_ems) { FactoryGirl.create(:ems_redhat, :zone => FactoryGirl.create(:zone)) }
      let(:dst_cluster) { FactoryGirl.create(:ems_cluster, :ext_management_system => dst_ems) }
      let(:dst_storage) { FactoryGirl.create(:storage) }
      let(:dst_lan_1) { FactoryGirl.create(:lan) }
      let(:dst_lan_2) { FactoryGirl.create(:lan) }
      let(:conversion_host) { FactoryGirl.create(:conversion_host, :resource => FactoryGirl.create(:host, :ext_management_system => dst_ems)) }

      let(:mapping) do
        FactoryGirl.create(
          :transformation_mapping,
          :transformation_mapping_items => [
            TransformationMappingItem.new(:source => src_cluster, :destination => dst_cluster),
            TransformationMappingItem.new(:source => src_storage, :destination => dst_storage),
            TransformationMappingItem.new(:source => src_lan_1, :destination => dst_lan_1),
            TransformationMappingItem.new(:source => src_lan_2, :destination => dst_lan_2)
          ]
        )
      end

      let(:catalog_item_options) do
        {
          :name        => 'Transformation Plan',
          :description => 'a description',
          :config_info => {
            :transformation_mapping_id => mapping.id,
            :pre_service_id            => apst.id,
            :post_service_id           => apst.id,
            :actions                   => [
              {:vm_id => src_vm.id.to_s, :pre_service => true, :post_service => true}
            ],
          }
        }
      end

      let(:plan) { ServiceTemplateTransformationPlan.create_catalog_item(catalog_item_options) }
      let(:request) { FactoryGirl.create(:service_template_transformation_plan_request, :source => plan) }
      let(:task) { FactoryGirl.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => src_vm, :conversion_host => conversion_host) }

      before do
        allow(task).to receive(:source_disks).and_return(source_disks)
        allow(conversion_host).to receive(:ipaddress).and_return('10.0.1.1')
      end

      context "transport method is vddk" do
        before do
          conversion_host.vddk_transport_supported = true
        end

        it "#conversion_options" do
          expect(conversion_host.conversion_options(task)).to eq(
            :vm_name             => src_vm.name,
            :transport_method    => 'vddk',
            :vmware_fingerprint  => '01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67',
            :vmware_uri          => "esx://esx_user@10.0.0.1/?no_verify=1",
            :vmware_password     => 'esx_passwd',
            :rhv_url             => "https://#{dst_ems.hostname}/ovirt-engine/api",
            :rhv_cluster         => dst_cluster.name,
            :rhv_storage         => dst_storage.name,
            :rhv_password        => dst_ems.authentication_password,
            :source_disks        => [src_disk_1.filename, src_disk_2.filename],
            :network_mappings    => task.network_mappings,
            :install_drivers     => true,
            :insecure_connection => true
          )
        end
      end

      context "transport method is ssh" do
        before do
          conversion_host.vddk_transport_supported = false
          conversion_host.ssh_transport_supported = true
        end

        it "#conversion_options" do
          expect(conversion_host.conversion_options(task)).to eq(
            :vm_name             => "ssh://root@10.0.0.1/vmfs/volumes/#{src_storage.name}/#{src_vm.location}",
            :transport_method    => 'ssh',
            :rhv_url             => "https://#{dst_ems.hostname}/ovirt-engine/api",
            :rhv_cluster         => dst_cluster.name,
            :rhv_storage         => dst_storage.name,
            :rhv_password        => dst_ems.authentication_password,
            :source_disks        => [src_disk_1.filename, src_disk_2.filename],
            :network_mappings    => task.network_mappings,
            :install_drivers     => true,
            :insecure_connection => true
          )
        end
      end
    end

    context "destination is openstack" do
      let(:dst_ems) { FactoryGirl.create(:ems_openstack, :zone => FactoryGirl.create(:zone)) }
      let(:dst_cloud_tenant) { FactoryGirl.create(:cloud_tenant, :ext_management_system => dst_ems) }
      let(:dst_cloud_volume_type) { FactoryGirl.create(:cloud_volume_type) }
      let(:dst_cloud_network_1) { FactoryGirl.create(:cloud_network) }
      let(:dst_cloud_network_2) { FactoryGirl.create(:cloud_network) }
      let(:dst_flavor) { FactoryGirl.create(:flavor) }
      let(:dst_security_group) { FactoryGirl.create(:security_group) }
      let(:conversion_host) { FactoryGirl.create(:conversion_host, :resource => FactoryGirl.create(:vm_or_template, :ext_management_system => dst_ems)) }

      let(:mapping) do
        FactoryGirl.create(
          :transformation_mapping,
          :transformation_mapping_items => [
            TransformationMappingItem.new(:source => src_cluster, :destination => dst_cloud_tenant),
            TransformationMappingItem.new(:source => src_storage, :destination => dst_cloud_volume_type),
            TransformationMappingItem.new(:source => src_lan_1, :destination => dst_cloud_network_1),
            TransformationMappingItem.new(:source => src_lan_2, :destination => dst_cloud_network_2)
          ]
        )
      end

      let(:catalog_item_options) do
        {
          :name        => 'Transformation Plan',
          :description => 'a description',
          :config_info => {
            :transformation_mapping_id => mapping.id,
            :pre_service_id            => apst.id,
            :post_service_id           => apst.id,
            :osp_flavor                => dst_flavor.id,
            :osp_security_group        => dst_security_group.id,
            :actions                   => [
              {:vm_id => src_vm.id.to_s, :pre_service => true, :post_service => true}
            ],
          }
        }
      end

      let(:plan) { ServiceTemplateTransformationPlan.create_catalog_item(catalog_item_options) }
      let(:request) { FactoryGirl.create(:service_template_transformation_plan_request, :source => plan) }
      let(:task) { FactoryGirl.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => src_vm, :conversion_host => conversion_host) }

      before do
        allow(task).to receive(:source_disks).and_return(source_disks)
      end

      context "transport method is vddk" do
        before do
          conversion_host.vddk_transport_supported = true
        end

        it "#conversion_options" do
          expect(conversion_host.conversion_options(task)).to eq(
            :vm_name                    => src_vm.name,
            :transport_method           => 'vddk',
            :vmware_fingerprint         => '01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67',
            :vmware_uri                 => "esx://esx_user@10.0.0.1/?no_verify=1",
            :vmware_password            => 'esx_passwd',
            :osp_environment            => {
              :os_no_cache         => true,
              :os_auth_url         => URI::Generic.build(
                :scheme => dst_ems.security_protocol == 'non-ssl' ? 'http' : 'https',
                :host   => dst_ems.hostname,
                :port   => dst_ems.port,
                :path   => dst_ems.api_version
              ),
              :os_user_domain_name => dst_ems.uid_ems,
              :os_username         => dst_ems.authentication_userid,
              :os_password         => dst_ems.authentication_password,
              :os_project_name     => dst_cloud_tenant.name
            },
            :osp_destination_project_id => dst_cloud_tenant.ems_ref,
            :osp_volume_type_id         => dst_cloud_volume_type.ems_ref,
            :osp_flavor_id              => dst_flavor.ems_ref,
            :osp_security_groups_ids    => [dst_security_group.ems_ref],
            :source_disks               => [src_disk_1.filename, src_disk_2.filename],
            :network_mappings           => task.network_mappings
          )
        end
      end

      context "transport method is ssh" do
        before do
          conversion_host.vddk_transport_supported = false
          conversion_host.ssh_transport_supported = true
        end

        it "#conversion_options" do
          expect(conversion_host.conversion_options(task)).to eq(
            :vm_name                    => "ssh://root@10.0.0.1/vmfs/volumes/#{src_storage.name}/#{src_vm.location}",
            :transport_method           => 'ssh',
            :osp_environment            => {
              :os_no_cache         => true,
              :os_auth_url         => URI::Generic.build(
                :scheme => dst_ems.security_protocol == 'non-ssl' ? 'http' : 'https',
                :host   => dst_ems.hostname,
                :port   => dst_ems.port,
                :path   => dst_ems.api_version
              ),
              :os_user_domain_name => dst_ems.uid_ems,
              :os_username         => dst_ems.authentication_userid,
              :os_password         => dst_ems.authentication_password,
              :os_project_name     => dst_cloud_tenant.name
            },
            :osp_destination_project_id => dst_cloud_tenant.ems_ref,
            :osp_volume_type_id         => dst_cloud_volume_type.ems_ref,
            :osp_flavor_id              => dst_flavor.ems_ref,
            :osp_security_groups_ids    => [dst_security_group.ems_ref],
            :source_disks               => [src_disk_1.filename, src_disk_2.filename],
            :network_mappings           => task.network_mappings
          )
        end
      end
    end
  end
end
