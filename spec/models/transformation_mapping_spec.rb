describe TransformationMapping do
  let(:src_ems) { FactoryGirl.create(:ems_vmware) }
  let(:dst_ems_redhat) { FactoryGirl.create(:ems_redhat) }
  let(:dst_ems_openstack) { FactoryGirl.create(:ems_openstack) }
  let(:src_cluster) { FactoryGirl.create(:ems_cluster, :ext_management_system => src_ems) }
  let(:dst_cluster_redhat) { FactoryGirl.create(:ems_cluster, :ext_management_system => dst_ems_redhat) }
  let(:dst_cloud_tenant_openstack) { FactoryGirl.create(:cloud_tenant, :ext_management_system => dst_ems_openstack) }
  let(:vm)  { FactoryGirl.create(:vm_vmware, :ems_cluster => src_cluster) }

  let(:mapping_redhat) do
    FactoryGirl.create(
      :transformation_mapping,
      :transformation_mapping_items => [TransformationMappingItem.new(:source => src_cluster, :destination => dst_cluster_redhat)]
    )
  end

  let(:mapping_openstack) do
    FactoryGirl.create(
      :transformation_mapping,
      :transformation_mapping_items => [TransformationMappingItem.new(:source => src_cluster, :destination => dst_cloud_tenant_openstack)]
    )
  end

  describe '#destination' do
    it "finds the destination" do
      expect(mapping_redhat.destination(src_cluster)).to eq(dst_cluster_redhat)
    end

    it "returns nil for unmapped source" do
      expect(mapping_redhat.destination(FactoryGirl.create(:ems_cluster))).to be_nil
    end
  end

  describe '#service_templates' do
    let(:plan) { FactoryGirl.create(:service_template_transformation_plan) }
    before { FactoryGirl.create(:service_resource, :resource => mapping_redhat, :service_template => plan) }

    it 'finds the transformation plans' do
      expect(mapping_redhat.service_templates).to match([plan])
    end
  end

  describe '#search_vms_and_validate' do
    let(:vm) { FactoryGirl.create(:vm_vmware, :name => 'test_vm', :ems_cluster => src_cluster, :ext_management_system => FactoryGirl.create(:ext_management_system)) }
    let(:vm2) { FactoryGirl.create(:vm_vmware, :ems_cluster => src_cluster, :ext_management_system => FactoryGirl.create(:ext_management_system)) }
    let(:inactive_vm) { FactoryGirl.create(:vm_vmware, :name => 'test_vm_inactive', :ems_cluster => src_cluster, :ext_management_system => nil) }
    let(:storage) { FactoryGirl.create(:storage) }
    let(:lan) { FactoryGirl.create(:lan) }
    let(:nic) { FactoryGirl.create(:guest_device_nic, :lan => lan) }

    before do
      mapping_redhat.transformation_mapping_items << TransformationMappingItem.new(:source => storage, :destination => storage)
      mapping_redhat.transformation_mapping_items << TransformationMappingItem.new(:source => lan, :destination => lan)
      vm.storages << storage
      vm.hardware = FactoryGirl.create(:hardware, :guest_devices => [nic])
    end

    context 'with VM list' do
      context 'returns invalid vms' do
        it 'if VM has an invalid name in rhevm' do
          name = ' not allowed'
          FactoryBot.create(:vm_vmware, :name => name, :ems_cluster => src_cluster, :ext_management_system => FactoryGirl.create(:ext_management_system))
          result = mapping_redhat.search_vms_and_validate(['name' => name])
          expect(result['invalid'].first.reason).to eq(TransformationMapping::VmMigrationValidator::VM_UNSUPPORTED_NAME)
        end

        it 'if VM has an invalid name in openstack' do
          name = 7.chr # beep, non-printable
          FactoryBot.create(:vm_vmware, :name => name, :ems_cluster => src_cluster, :ext_management_system => src_ems)
          result = mapping_openstack.search_vms_and_validate(['name' => name])
          expect(result['invalid'].first.reason).to eq(TransformationMapping::VmMigrationValidator::VM_UNSUPPORTED_NAME)
        end

        it 'if VM does not exist' do
          result = mapping_redhat.search_vms_and_validate(['name' => 'vm1'])
          expect(result['invalid'].first.reason).to eq(TransformationMapping::VmMigrationValidator::VM_NOT_EXIST)
        end

        it 'if VM is inactive' do
          inactive_vm.storages << FactoryGirl.create(:storage, :name => 'storage_for_inactive_vm')
          result = mapping_redhat.search_vms_and_validate(['name' => 'test_vm_inactive'])
          expect(result['invalid'].first.reason).to eq(TransformationMapping::VmMigrationValidator::VM_INACTIVE)
        end

        it "if VM's cluster is not in the mapping" do
          FactoryGirl.create(
            :vm_vmware,
            :name                  => 'vm2',
            :ems_cluster           => FactoryGirl.create(:ems_cluster, :name => 'cluster1'),
            :ext_management_system => FactoryGirl.create(:ext_management_system)
          )
          result = mapping_redhat.search_vms_and_validate(['name' => 'vm2'])
          expect(result['invalid'].first.reason).to match(/not_exist/)
        end

        it "if VM's storages are not all in the mapping" do
          vm.storages << FactoryGirl.create(:storage, :name => 'storage2')
          result = mapping_redhat.search_vms_and_validate(['name' => vm.name])
          expect(result['invalid'].first.reason).to match(/Mapping source not found - storages: storage2/)
        end

        it "if VM's lans are not all in the mapping" do
          vm.hardware.guest_devices << FactoryGirl.create(:guest_device_nic, :lan =>FactoryGirl.create(:lan, :name => 'lan2'))
          result = mapping_redhat.search_vms_and_validate(['name' => vm.name])
          expect(result['invalid'].first.reason).to match(/Mapping source not found - lans: lan2/)
        end

        it "if any source is invalid" do
          vm.storages << FactoryGirl.create(:storage, :name => 'storage2')
          vm.hardware.guest_devices << FactoryGirl.create(:guest_device_nic, :lan =>FactoryGirl.create(:lan, :name => 'lan2'))
          result = mapping_redhat.search_vms_and_validate(['name' => vm.name])
          expect(result['invalid'].first.reason).to match(/Mapping source not found - storages: storage2. lans: lan2/)
        end

        it 'if VM is in another migration plan' do
          %w(Queued Approved Active).each do |status|
            FactoryGirl.create(
              :service_resource,
              :resource         => vm,
              :service_template => FactoryGirl.create(:service_template_transformation_plan),
              :status           => status
            )

            result = mapping_redhat.search_vms_and_validate(['name' => vm.name])
            expect(result['invalid'].first.reason).to match(/in_other_plan/)
          end
        end

        it 'if VM has been migrated' do
          FactoryGirl.create(
            :service_resource,
            :resource         => vm,
            :service_template => FactoryGirl.create(:service_template_transformation_plan),
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
        FactoryGirl.create(:vm_vmware, :name => 'test_vm', :ems_cluster => src_cluster, :ext_management_system => FactoryGirl.create(:ext_management_system))
        result = mapping_redhat.search_vms_and_validate(['name' => vm.name])
        expect(result['conflicted'].first.reason).to eq(TransformationMapping::VmMigrationValidator::VM_CONFLICT)
      end
    end

    context 'with VM list and service_template_id' do
      it 'returns valid vms when a ServiceTemplate record is edited with CSV containing the same VM already included in the ServiceTemplate record' do
        service_template = FactoryGirl.create(:service_template_transformation_plan)

        FactoryGirl.create(
          :service_resource,
          :resource         => vm2,
          :service_template => service_template,
          :status           => "Active"
        )
        result = mapping_redhat.search_vms_and_validate(['name' => vm2.name], service_template.id.to_s)
        expect(result['valid'].first.reason).to match(/ok/)
      end

      it 'returns invalid vms when the Service Template record is edited with CSV containing a different VM that belongs to a different ServiceTemplate record' do
        service_template = FactoryGirl.create(:service_template_transformation_plan)
        service_template2 = FactoryGirl.create(:service_template_transformation_plan)

        FactoryGirl.create(
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
        FactoryGirl.create(
          :vm_vmware,
          :name                  => 'vm2',
          :ems_cluster           => FactoryGirl.create(:ems_cluster, :name => 'cluster1'),
          :ext_management_system => FactoryGirl.create(:ext_management_system)
        )
        result = mapping_redhat.search_vms_and_validate
        expect(result['valid'].count).to eq(1)
      end
    end
  end
end
