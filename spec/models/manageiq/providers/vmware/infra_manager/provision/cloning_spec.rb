describe ManageIQ::Providers::Vmware::InfraManager::Provision::Cloning do
  context "#dest_folder" do
    before do
      @os = FactoryGirl.create(:operating_system)
      @admin = FactoryGirl.create(:user_admin)
      @target_vm_name = 'clone test'
      @options = {
        :pass          => 1,
        :vm_name       => @target_vm_name,
        :number_of_vms => 1,
        :cpu_limit     => -1,
        :cpu_reserve   => 0
      }
      @ems         = FactoryGirl.create(:ems_vmware_with_authentication, :api_version => '6.0')
      @vm_template = FactoryGirl.create(:template_vmware, :name => "template1", :ext_management_system => @ems, :operating_system => @os, :cpu_limit => -1, :cpu_reserve => 0)
      @pr          = FactoryGirl.create(:miq_provision_request, :requester => @admin, :src_vm_id => @vm_template.id)
      @options[:src_vm_id] = [@vm_template.id, @vm_template.name]
      @vm_prov = FactoryGirl.create(:miq_provision_vmware, :userid => @admin.userid, :miq_request => @pr, :source => @vm_template, :request_type => 'template', :state => 'pending', :status => 'Ok', :options => @options)
    end

    let(:folder_name) { 'folder_one' }
    let(:ems_folder)  { double('ems_folder') }
    let(:dest_host) do
      FactoryGirl.create(:host_vmware, :ext_management_system => ems)
    end

    let(:dc_nested) do
      EvmSpecHelper::EmsMetadataHelper.vmware_nested_folders(@ems)
    end

    let(:dest_host_nested) do
      FactoryGirl.create(:host_vmware, :ext_management_system => @ems).tap { |h| h.parent = dc_nested }
    end

    let(:vm_folder_nested) do
      FactoryGirl.create(:ems_folder, :name => 'vm', :ems_id => @ems.id).tap { |v| v.parent = dc_nested }
    end

    it "returns a folder if one is found" do
      expect(EmsFolder).to receive(:find_by).and_return(:ems_folder)
      expect(@vm_prov).to receive(:find_folder).never
      @vm_prov.dest_folder
    end

    it "attempts to find a usable folder if the ems_folder does not exist" do
      @vm_prov.options[:dest_host] = [dest_host_nested.id, dest_host_nested.name]
      expect(@vm_prov).to receive(:find_folder).once
      @vm_prov.dest_folder
    end
  end
end
