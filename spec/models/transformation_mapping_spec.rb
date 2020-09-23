RSpec.describe TransformationMapping, :v2v do
  let(:src_ems_vmware)    { FactoryBot.create(:ems_vmware) }
  let(:dst_ems_redhat)    { FactoryBot.create(:ems_redhat) }
  let(:dst_ems_openstack) { FactoryBot.create(:ems_openstack) }

  let(:src_cluster_vmware) { FactoryBot.create(:ems_cluster, :ext_management_system => src_ems_vmware) }
  let(:dst_cluster_redhat) { FactoryBot.create(:ems_cluster, :ext_management_system => dst_ems_redhat) }

  let(:src_hosts_vmware) { FactoryBot.create_list(:host_vmware, 1, :ems_cluster => src_cluster_vmware) }
  let(:dst_hosts_redhat) { FactoryBot.create_list(:host_redhat, 1, :ems_cluster => dst_cluster_redhat) }

  let(:src_storages_vmware) { FactoryBot.create_list(:storage, 1, :hosts => src_hosts_vmware) }
  let(:dst_storages_redhat) { FactoryBot.create_list(:storage, 1, :hosts => dst_hosts_redhat) }

  let(:src_switches_vmware) { FactoryBot.create_list(:switch, 1, :hosts => src_hosts_vmware) }
  let(:dst_switches_redhat) { FactoryBot.create_list(:switch, 1, :hosts => dst_hosts_redhat) }

  let(:src_lans_vmware) { FactoryBot.create_list(:lan, 1, :switch => src_switches_vmware.first) }
  let(:dst_lans_redhat) { FactoryBot.create_list(:lan, 1, :switch => dst_switches_redhat.first) }

  let(:dst_cloud_tenant_openstack) { FactoryBot.create(:cloud_tenant, :ext_management_system => dst_ems_openstack) }

  let(:mapping_redhat) do
    FactoryBot.create(:transformation_mapping).tap do |tm|
      FactoryBot.create(:transformation_mapping_item,
        :source                 => src_cluster_vmware,
        :destination            => dst_cluster_redhat,
        :transformation_mapping => tm
      )
      FactoryBot.create(:transformation_mapping_item,
        :source                 => src_storages_vmware.first,
        :destination            => dst_storages_redhat.first,
        :transformation_mapping => tm
      )
      FactoryBot.create(:transformation_mapping_item,
        :source                 => src_lans_vmware.first,
        :destination            => dst_lans_redhat.first,
        :transformation_mapping => tm
      )
    end
  end

  let(:mapping_openstack) do
    FactoryBot.create(:transformation_mapping).tap do |tm|
      tm.transformation_mapping_items = [
        FactoryBot.create(:transformation_mapping_item,
          :source                 => src_cluster_vmware,
          :destination            => dst_cloud_tenant_openstack,
          :transformation_mapping => tm
        )
      ]
    end
  end

  it "doesn't access database when unchanged model is saved" do
    m = FactoryBot.create(:transformation_mapping)
    expect { m.valid? }.not_to make_database_queries
  end

  context '#destination' do
    it "finds the destination" do
      expect(mapping_redhat.destination(src_cluster_vmware)).to eq(dst_cluster_redhat)
    end

    it "returns nil for unmapped source" do
      expect(mapping_redhat.destination(FactoryBot.create(:ems_cluster))).to be_nil
    end
  end

  context '#service_templates' do
    let(:plan) { FactoryBot.create(:service_template_transformation_plan) }
    before { FactoryBot.create(:service_resource, :resource => mapping_redhat, :service_template => plan) }

    it 'finds the transformation plans' do
      expect(mapping_redhat.service_templates).to match([plan])
    end
  end

  context '#search_vms_and_validate' do
    let(:nics) { FactoryBot.create_list(:guest_device_nic, 1, :lan => src_lans_vmware.first) }
    let(:hardware) { FactoryBot.create(:hardware, :guest_devices => nics) }

    let!(:vm) do
      FactoryBot.create(
        :vm_vmware,
        :name                  => 'test_vm',
        :ems_cluster           => src_cluster_vmware,
        :ext_management_system => src_cluster_vmware.ext_management_system,
        :storages              => src_storages_vmware,
        :hardware              => hardware
      )
    end

    let(:vm2) do
      FactoryBot.create(
        :vm_vmware,
        :ems_cluster           => src_cluster_vmware,
        :ext_management_system => src_cluster_vmware.ext_management_system,
        :storages              => src_storages_vmware
      )
    end

    let(:inactive_vm) do
      FactoryBot.create(
        :vm_vmware,
        :name                  => 'test_vm_inactive',
        :ems_cluster           => src_cluster_vmware,
        :ext_management_system => nil
      )
    end

    context 'with VM list' do
      context 'returns invalid vms' do
        it 'if VM has an invalid name in rhevm' do
          name = ' not allowed'
          FactoryBot.create(:vm_vmware, :name => name, :ems_cluster => src_cluster_vmware, :ext_management_system => src_ems_vmware)
          result = mapping_redhat.search_vms_and_validate(['name' => name])
          expect(result['invalid'].first.reason).to eq(TransformationMapping::VmMigrationValidator::VM_UNSUPPORTED_NAME)
        end

        it 'if VM has an invalid name in openstack' do
          name = 7.chr # beep, non-printable
          FactoryBot.create(:vm_vmware, :name => name, :ems_cluster => src_cluster_vmware, :ext_management_system => src_ems_vmware)
          result = mapping_openstack.search_vms_and_validate(['name' => name])
          expect(result['invalid'].first.reason).to eq(TransformationMapping::VmMigrationValidator::VM_UNSUPPORTED_NAME)
        end

        it 'if VM does not exist' do
          result = mapping_redhat.search_vms_and_validate(['name' => 'vm1'])
          expect(result['invalid'].first.reason).to eq(TransformationMapping::VmMigrationValidator::VM_NOT_EXIST)
        end

        it 'if VM is inactive' do
          inactive_vm.storages << FactoryBot.create(:storage, :name => 'storage_for_inactive_vm')
          result = mapping_redhat.search_vms_and_validate(['name' => 'test_vm_inactive'])
          expect(result['invalid'].first.reason).to eq(TransformationMapping::VmMigrationValidator::VM_INACTIVE)
        end

        it "if VM's cluster is not in the mapping" do
          FactoryBot.create(
            :vm_vmware,
            :ems_cluster           => FactoryBot.create(:ems_cluster, :name => 'cluster1'),
            :ext_management_system => FactoryBot.create(:ext_management_system)
          )
          result = mapping_redhat.search_vms_and_validate(['name' => 'vm2'])
          expect(result['invalid'].first.reason).to match(/not_exist/)
        end

        it "if VM's storages are not all in the mapping" do
          vm.storages << FactoryBot.create(:storage, :name => 'storage2')
          result = mapping_redhat.search_vms_and_validate(['name' => vm.name])
          expect(result['invalid'].first.reason).to match(/Mapping source not found - storages: storage2/)
        end

        it "if VM's lans are not all in the mapping" do
          vm.hardware.guest_devices << FactoryBot.create(:guest_device_nic, :lan =>FactoryBot.create(:lan, :name => 'lan2'))
          result = mapping_redhat.search_vms_and_validate(['name' => vm.name])
          expect(result['invalid'].first.reason).to match(/Mapping source not found - lans: lan2/)
        end

        it "if any source is invalid" do
          vm.storages << FactoryBot.create(:storage, :name => 'storage2')
          vm.hardware.guest_devices << FactoryBot.create(:guest_device_nic, :lan =>FactoryBot.create(:lan, :name => 'lan2'))
          result = mapping_redhat.search_vms_and_validate(['name' => vm.name])
          expect(result['invalid'].first.reason).to match(/Mapping source not found - storages: storage2. lans: lan2/)
        end

        it 'if VM is in another migration plan' do
          %w[Queued Approved Active].each do |status|
            FactoryBot.create(
              :service_resource,
              :resource         => vm,
              :service_template => FactoryBot.create(:service_template_transformation_plan),
              :status           => status
            )

            result = mapping_redhat.search_vms_and_validate(['name' => vm.name])
            expect(result['invalid'].first.reason).to match(/in_other_plan/)
          end
        end

        it 'if VM has been migrated' do
          FactoryBot.create(
            :service_resource,
            :resource         => vm,
            :service_template => FactoryBot.create(:service_template_transformation_plan),
            :status           => 'Completed'
          )

          result = mapping_redhat.search_vms_and_validate(['name' => vm.name])
          expect(result['invalid'].first.reason).to match(/migrated/)
        end
      end

      it 'returns valid vms' do
        result = mapping_redhat.search_vms_and_validate(['name' => vm.name])
        expect(result['valid'].first.reason).to eq(TransformationMapping::VmMigrationValidator::VM_VALID)
        expect(result['valid'].first.ems_cluster_id).to eq(vm.ems_cluster_id.to_s)
      end

      it 'returns conflict vms' do
        FactoryBot.create(:vm_vmware, :name => 'test_vm', :ems_cluster => src_cluster_vmware, :ext_management_system => FactoryBot.create(:ext_management_system))
        result = mapping_redhat.search_vms_and_validate(['name' => vm.name])
        expect(result['conflicted'].first.reason).to eq(TransformationMapping::VmMigrationValidator::VM_CONFLICT)
      end
    end

    context 'with VM list and service_template_id' do
      it 'returns valid vms when a ServiceTemplate record is edited with CSV containing the same VM already included in the ServiceTemplate record' do
        service_template = FactoryBot.create(:service_template_transformation_plan)

        FactoryBot.create(
          :service_resource,
          :resource         => vm2,
          :service_template => service_template,
          :status           => "Active"
        )
        result = mapping_redhat.search_vms_and_validate(['name' => vm2.name], service_template.id.to_s)
        expect(result['valid'].first.reason).to match(/ok/)
      end

      it 'returns invalid vms when the Service Template record is edited with CSV containing a different VM that belongs to a different ServiceTemplate record' do
        service_template = FactoryBot.create(:service_template_transformation_plan)
        service_template2 = FactoryBot.create(:service_template_transformation_plan)

        FactoryBot.create(
          :service_resource,
          :resource         => vm2,
          :service_template => service_template,
          :status           => "Active"
        )
        result = mapping_redhat.search_vms_and_validate(['name' => vm2.name], service_template2.id.to_s)
        expect(result['invalid'].first.reason).to match(/in_other_plan/)
      end
    end

    context 'without VM list' do
      it 'returns valid vms' do
        result = mapping_redhat.search_vms_and_validate
        expect(result['valid'].count).to eq(1)
      end

      it 'skips invalid vms' do
        FactoryBot.create(
          :vm_vmware,
          :name                  => 'vm2',
          :ems_cluster           => FactoryBot.create(:ems_cluster, :name => 'cluster1'),
          :ext_management_system => FactoryBot.create(:ext_management_system)
        )
        result = mapping_redhat.search_vms_and_validate
        expect(result['valid'].count).to eq(1)
      end
    end
  end
end
