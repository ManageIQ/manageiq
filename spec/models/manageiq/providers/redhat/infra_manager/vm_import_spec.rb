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

  let(:new_name) { 'created-vm' }

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

    it 'passes the proper params to oVirt API' do
      vcenter = source_ems.endpoints.first.hostname
      url = "vpx://testuser@#{vcenter}/#{cluster_path_escaped}/#{source_host.ipaddress}?no_verify=1"
      import_params = OvirtSDK4::ExternalVmImport.new(
        :name           => source_vm.name,
        :vm             => { :name => new_name },
        :provider       => OvirtSDK4::ExternalVmProviderType::VMWARE,
        :username       => 'testuser',
        :password       => 'secret',
        :url            => url,
        :cluster        => { :id => cluster.uid_ems },
        :storage_domain => { :id => storage.ems_ref_obj.split('/').last },
        :sparse         => true
      )
      expect_any_instance_of(OvirtSDK4::ExternalVmImportsService).to receive(:add).with(eq(import_params))
      target_ems.import_vm(
        source_vm.id,
        :name       => new_name,
        :cluster_id => cluster.id,
        :storage_id => storage.id,
        :sparse     => true
      )
    end
  end
end
