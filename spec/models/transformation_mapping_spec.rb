describe TransformationMapping do
  let(:src) { FactoryGirl.create(:ems_cluster) }
  let(:dst) { FactoryGirl.create(:ems_cluster) }
  let(:vm)  { FactoryGirl.create(:vm_vmware, :ems_cluster => src) }

  let(:mapping) do
    FactoryGirl.create(
      :transformation_mapping,
      :transformation_mapping_items => [TransformationMappingItem.new(:source => src, :destination => dst)]
    )
  end

  describe '#destination' do
    it "finds the destination" do
      expect(mapping.destination(src)).to eq(dst)
    end

    it "returns nil for unmapped source" do
      expect(mapping.destination(FactoryGirl.create(:ems_cluster))).to be_nil
    end
  end

  describe '#service_templates' do
    let(:plan) { FactoryGirl.create(:service_template_transformation_plan) }
    before { FactoryGirl.create(:service_resource, :resource => mapping, :service_template => plan) }

    it 'finds the transformation plans' do
      expect(mapping.service_templates).to match([plan])
    end
  end

  describe '#validate_vms' do
    let(:vm) { FactoryGirl.create(:vm_vmware, :name => 'test_vm', :ems_cluster => src, :ext_management_system => FactoryGirl.create(:ext_management_system)) }
    let(:storage) { FactoryGirl.create(:storage) }
    let(:lan) { FactoryGirl.create(:lan) }
    let(:nic) { FactoryGirl.create(:guest_device_nic, :lan => lan) }

    before do
      mapping.transformation_mapping_items << TransformationMappingItem.new(:source => storage, :destination => storage)
      mapping.transformation_mapping_items << TransformationMappingItem.new(:source => lan, :destination => lan)
      vm.storages << storage
      vm.hardware = FactoryGirl.create(:hardware, :guest_devices => [nic])
    end

    context 'with VM list' do
      context 'returns invalid vms' do
        it 'if VM does not exist' do
          result = mapping.validate_vms(['name' => 'vm1'])
          expect(result['invalid_vms'].first).to match(hash_including('reason' => TransformationMapping::VM_NOT_EXIST))
        end

        it "if VM's cluster is not in the mapping" do
          FactoryGirl.create(
            :vm_vmware,
            :name                  => 'vm2',
            :ems_cluster           => FactoryGirl.create(:ems_cluster, :name => 'cluster1'),
            :ext_management_system => FactoryGirl.create(:ext_management_system)
          )
          result = mapping.validate_vms(['name' => 'vm2'])
          expect(result['invalid_vms'].first['reason']).to match(/Mapping source not found - cluster: cluster1/)
        end

        it "if VM's storages are not all in the mapping" do
          vm.storages << FactoryGirl.create(:storage, :name => 'storage2')
          result = mapping.validate_vms(['name' => vm.name])
          expect(result['invalid_vms'].first['reason']).to match(/Mapping source not found - storages: storage2/)
        end

        it "if VM's lans are not all in the mapping" do
          vm.hardware.guest_devices << FactoryGirl.create(:guest_device_nic, :lan =>FactoryGirl.create(:lan, :name => 'lan2'))
          result = mapping.validate_vms(['name' => vm.name])
          expect(result['invalid_vms'].first['reason']).to match(/Mapping source not found - lans: lan2/)
        end

        it "if any source is invalid" do
          vm.storages << FactoryGirl.create(:storage, :name => 'storage2')
          vm.hardware.guest_devices << FactoryGirl.create(:guest_device_nic, :lan =>FactoryGirl.create(:lan, :name => 'lan2'))
          result = mapping.validate_vms(['name' => vm.name])
          expect(result['invalid_vms'].first['reason']).to match(/Mapping source not found - storages: storage2. lans: lan2/)
        end

        it 'if VM is in another migration plan' do
          %w(Queued Approved Active).each do |status|
            FactoryGirl.create(
              :service_resource,
              :resource         => vm,
              :service_template => FactoryGirl.create(:service_template_transformation_plan),
              :status           => status
            )

            result = mapping.validate_vms(['name' => vm.name])
            expect(result['invalid_vms'].first['reason']).to match(/in_other_plan/)
          end
        end

        it 'if VM has been migrated' do
          FactoryGirl.create(
            :service_resource,
            :resource         => vm,
            :service_template => FactoryGirl.create(:service_template_transformation_plan),
            :status           => 'Completed'
          )

          result = mapping.validate_vms(['name' => vm.name])
          expect(result['invalid_vms'].first['reason']).to match(/migrated/)
        end
      end

      it 'returns valid vms' do
        result = mapping.validate_vms(['name' => vm.name])
        expect(result['valid_vms'].first).to match(hash_including('reason' => TransformationMapping::VM_VALID))
      end

      it 'returns conflict vms' do
        FactoryGirl.create(:vm_vmware, :name => 'test_vm', :ems_cluster => src, :ext_management_system => FactoryGirl.create(:ext_management_system))
        result = mapping.validate_vms(['name' => vm.name])
        expect(result['conflict_vms'].first).to match(hash_including('reason' => TransformationMapping::VM_CONFLICT))
      end
    end

    context 'without VM list' do
      it 'returns valid vms' do
        result = mapping.validate_vms
        expect(result['valid_vms'].count).to eq(1)
      end

      it 'skips invalid vms' do
        FactoryGirl.create(
          :vm_vmware,
          :name                  => 'vm2',
          :ems_cluster           => FactoryGirl.create(:ems_cluster, :name => 'cluster1'),
          :ext_management_system => FactoryGirl.create(:ext_management_system)
        )
        result = mapping.validate_vms
        expect(result['valid_vms'].count).to eq(1)
      end
    end
  end
end
