describe ManageIQ::Providers::Redhat::InfraManager::VmImport do
  let(:target_ems)  { FactoryGirl.create(:ems_redhat_with_authentication) }
  let(:source_ems)  { FactoryGirl.create(:ems_vmware_with_authentication) }
  let(:source_vm)   { FactoryGirl.create(:vm_with_ref, :ext_management_system => source_ems) }
  let(:pool)        { FactoryGirl.create(:resource_pool) }
  let(:source_host) { FactoryGirl.create(:host) }
  let(:cluster)     { FactoryGirl.create(:ems_cluster) }
  let(:storage)     { FactoryGirl.create(:storage_redhat) }

  let(:cluster_path)          { 'Folder1/Folder @#$*2/Compute 3/Folder4/Cluster 5' }
  let(:cluster_path_escaped)  { 'Folder1%2FFolder%20%40%23%24*2%2FCompute%203%2FFolder4%2FCluster%205' }

  let(:cluster_guid) { cluster.uid_ems }
  let(:storage_guid) { storage.ems_ref_obj.split('/').last }

  let(:new_name)  { 'created-vm' }
  let(:new_vm_id) { '6820ad2a-a8c0-4b4e-baf2-3482357ba352' }
  let(:vcenter)   { source_ems.endpoints.first.hostname }
  let(:url)       { "vpx://testuser@#{vcenter}/#{cluster_path_escaped}/#{source_host.ipaddress}?no_verify=1" }
  let(:iso_name)  { 'RHEV-toolsSetup_4.1_5.iso' }

  let(:vm_import_response) do
    OvirtSDK4::ExternalVmImport.new(
      :vm => OvirtSDK4::Vm.new(
        :id   => new_vm_id,
        :href => "/ovirt-engine/api/vms/#{new_vm_id}"
      )
    )
  end

  context 'import url encoding' do
    describe '#escape_cluster' do
      it 'properly escapes Vmware cluster path' do
        expect(target_ems.send(:escape_cluster, cluster_path)).to eq(cluster_path_escaped)
      end
    end
  end

  require 'ovirtsdk4'

  describe '#import_vm' do
    before(:each) do
      allow_any_instance_of(Vm).to receive_message_chain(:parent_resource_pool, :absolute_path) { cluster_path }
      allow(target_ems).to receive(:check_import_supported!).and_return(true)
      allow(target_ems).to receive(:select_host).and_return(source_host)
      allow(OvirtSDK4::Probe).to receive(:probe).and_return([OvirtSDK4::ProbeResult.new(:version => '4')])
    end

    def expect_import(params, expected_request)
      expect_any_instance_of(OvirtSDK4::ExternalVmImportsService).to receive(:add).with(eq(expected_request)).and_return(vm_import_response)
      new_ems_ref = target_ems.import_vm(source_vm.id, params)
      expect(new_ems_ref).to eq("/api/vms/#{new_vm_id}")
    end

    context 'when called without ISO drivers' do
      it 'passes the proper params to oVirt API' do
        params = {
          :name       => new_name,
          :cluster_id => cluster.id,
          :storage_id => storage.id,
          :sparse     => true
        }
        import = OvirtSDK4::ExternalVmImport.new(
          :name           => source_vm.name,
          :vm             => { :name => new_name },
          :provider       => OvirtSDK4::ExternalVmProviderType::VMWARE,
          :username       => 'testuser',
          :password       => 'secret',
          :url            => url,
          :cluster        => { :id => cluster_guid },
          :storage_domain => { :id => storage_guid },
          :sparse         => true
        )
        expect_import(params, import)
      end
    end

    context 'when called with ISO drivers' do
      it 'passes the proper params to oVirt API' do
        params = {
          :name        => new_name,
          :cluster_id  => cluster.id,
          :storage_id  => storage.id,
          :sparse      => true,
          :drivers_iso => iso_name
        }
        import = OvirtSDK4::ExternalVmImport.new(
          :name           => source_vm.name,
          :vm             => { :name => new_name },
          :provider       => OvirtSDK4::ExternalVmProviderType::VMWARE,
          :username       => 'testuser',
          :password       => 'secret',
          :url            => url,
          :cluster        => { :id => cluster_guid },
          :storage_domain => { :id => storage_guid },
          :sparse         => true,
          :drivers_iso    => OvirtSDK4::File.new(:id => iso_name)
        )
        expect_import(params, import)
      end
    end
  end

  context 'checks version during validation' do
    let(:ems) { FactoryGirl.create(:ems_redhat) }

    it 'validates successfully' do
      allow(ems).to receive(:highest_supported_api_version).and_return('4')
      expect(ems.validate_import_vm).to be_truthy
    end

    it 'validates before connecting' do
      allow(ems).to receive(:highest_supported_api_version).and_return(nil)
      expect(ems.validate_import_vm).to be_falsey
    end
  end
end
