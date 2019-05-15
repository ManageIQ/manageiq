RSpec.describe TransformationMapping, :v2v do
  let(:ems_redhat) { FactoryBot.create(:ems_redhat, :zone => FactoryBot.create(:zone), :api_version => '4.2.4') }
  let(:ems_vmware) { FactoryBot.create(:ems_vmware, :zone => FactoryBot.create(:zone)) }

  let(:src) { FactoryBot.create(:ems_cluster, :ext_management_system => ems_vmware) }
  let(:dst) { FactoryBot.create(:ems_cluster, :ext_management_system => ems_redhat) }
  let(:vm)  { FactoryBot.create(:vm_vmware, :ems_cluster => src) }

  let(:mapping) do
    FactoryBot.create(
      :transformation_mapping,
      :transformation_mapping_items => [TransformationMappingItem.new(:source => src, :destination => dst)]
    )
  end

  let(:arifs_mapping) do
    FactoryBot.create(
      :transformation_mapping,
      :transformation_mapping_items => [TransformationMappingItem.new(:source => src, :destination => dst)]
    )
  end

  logger = Rails.logger

  describe '#search_vms_and_validate' do

    let(:source_cluster) { FactoryBot.create(:ems_cluster)}
    let(:source_host) { FactoryBot.create(:host, :ems_cluster => source_cluster) }
    let(:source_storage) { FactoryBot.create(:storage, :hosts => [source_host] ) }

    let(:destination_storage) { FactoryBot.create(:storage) }
    let(:destination_cluster) { FactoryBot.create(:ems_cluster)}
    let(:destination_host) { FactoryBot.create(:host, :ems_cluster => destination_cluster) }
    let(:destination_storage) { FactoryBot.create(:storage, :hosts => [destination_host] ) }

    let(:source_cluster) { FactoryBot.create(:ems_cluster ) }
    let(:source_host) { FactoryBot.create(:host, :ems_cluster => source_cluster) }
    let(:source_switch) { FactoryBot.create(:switch, :host => source_host) }
    let(:source_lan) { FactoryBot.create(:lan, :switch => source_switch)}

    let(:destination_cluster) { FactoryBot.create(:ems_cluster) }
    let(:destination_host) { FactoryBot.create(:host, :ems_cluster => destination_cluster) }
    let(:destination_switch) { FactoryBot.create(:switch, :host => destination_host) }
    let(:destination_lan) { FactoryBot.create(:lan, :switch => destination_switch)}

    let(:arifs_vm) { FactoryBot.create(:vm_vmware, :name => 'arifs_test_vm', :ems_cluster => src, :ext_management_system => FactoryBot.create(:ext_management_system)) }
    let(:vm) { FactoryBot.create(:vm_vmware, :name => 'test_vm', :ems_cluster => src, :ext_management_system => FactoryBot.create(:ext_management_system)) }
    let(:vm2) { FactoryBot.create(:vm_vmware, :ems_cluster => src, :ext_management_system => FactoryBot.create(:ext_management_system)) }
    let(:inactive_vm) { FactoryBot.create(:vm_vmware, :name => 'test_vm_inactive', :ems_cluster => src, :ext_management_system => nil) }
    let(:nic) { FactoryBot.create(:guest_device_nic, :lan => source_lan) }

    before do
    end

    context 'with VM list' do
      logger.info("CONTEXT: with VM list")
      it 'returns valid vms' do
        logger.info("TESTCASE: returns valid vms" )
        result = arifs_mapping.search_vms_and_validate(['name' => arifs_vm.name])
        expect(result['valid'].first.reason).to eq(TransformationMapping::VmMigrationValidator::VM_VALID)
        expect(result['valid'].first.ems_cluster_id).to eq(vm.ems_cluster_id.to_s)
      end

    end
=begin
    context 'without VM list' do
      logger.info("CONTEXT: without VM list")
      it 'returns valid vms' do
        logger.info("TESTCASE: returns valid vms" )
        result = mapping.search_vms_and_validate

        Rails.logger.info("ARIF - mapping in \"without VM list returns valid VMs\": " + mapping.to_s)

        expect(result['valid'].count).to eq(1)
        # expect(result['valid'].count).to eq(0)
      end

      it 'skips invalid vms' do
        logger.info("TESTCASE: skips invalid vms" )
        FactoryBot.create(
          :vm_vmware,
          :name                  => 'vm2',
          :ems_cluster           => FactoryBot.create(:ems_cluster, :name => 'cluster1'),
          :ext_management_system => FactoryBot.create(:ext_management_system)
        )
        Rails.logger.info("ARIF - mapping in \"without VM list - skips invalid VMs\": " + mapping.to_s)

        result = mapping.search_vms_and_validate

        Rails.logger.info("ARIF - mapping in \"without VM list - skips invalid VMs\": " + mapping.to_s)
        expect(result['valid'].count).to eq(1) # original
        # expect(result['valid'].count).to eq(0)
      end
    end
=end
  end
end
