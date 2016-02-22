describe "Vmware_best_fit_least_utilized" do
  let(:datacenter)  { FactoryGirl.create(:datacenter, :ext_management_system => ems) }
  let(:ems)         { FactoryGirl.create(:ems_vmware_with_authentication) }
  let(:ems_cluster) { FactoryGirl.create(:ems_cluster, :ext_management_system => ems) }
  let(:miq_provision) do
    FactoryGirl.create(:miq_provision_vmware,
                       :options      => {:src_vm_id => vm_template.id, :placement_auto => [true, 1]},
                       :userid       => user.userid,
                       :source       => vm_template,
                       :request_type => 'clone_to_vm',
                       :state        => 'active',
                       :status       => 'Ok')
  end
  let(:user)        { FactoryGirl.create(:user_with_group) }
  let(:vm_folder)   { FactoryGirl.create(:ems_folder, :ext_management_system => ems) }
  let(:vm_template) { FactoryGirl.create(:template_vmware, :ext_management_system => ems) }
  let(:ws) do
    MiqAeEngine.instantiate("/System/Request/Call_Instance_With_Message?" \
                            "namespace=Infrastructure/VM/Provisioning&class=Placement" \
                            "&instance=default&message=vmware&" \
                            "MiqProvision::miq_provision=#{miq_provision.id}", user)
  end

  context "Auto placement #set_folder" do
    it "host with a cluster" do
      host = FactoryGirl.create(:host_vmware, :storage, :ems_cluster => ems_cluster, :ext_management_system => ems)
      MiqServer.seed

      datacenter.with_relationship_type("ems_metadata") { datacenter.add_child(ems_cluster) }
      datacenter.with_relationship_type("ems_metadata") { datacenter.add_child(vm_folder) }
      vm_folder.with_relationship_type("ems_metadata")  { vm_folder.add_child(vm_template) }

      host_struct = [MiqHashStruct.new(:id => host.id, :evm_object_class => host.class.base_class.name.to_sym)]
      allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_hosts).and_return(host_struct)
      allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_folders).and_return([datacenter, vm_folder])

      ws.root

      expect(miq_provision.reload.options[:placement_folder_name]).to eq([vm_folder.id, vm_folder.name])
    end

    it "host without a cluster" do
      host = FactoryGirl.create(:host_vmware, :storage, :ext_management_system => ems)
      MiqServer.seed

      datacenter.with_relationship_type("ems_metadata") { datacenter.add_child(host) }
      datacenter.with_relationship_type("ems_metadata") { datacenter.add_child(vm_folder) }
      vm_folder.with_relationship_type("ems_metadata")  { vm_folder.add_child(vm_template) }

      host_struct = [MiqHashStruct.new(:id => host.id, :evm_object_class => host.class.base_class.name.to_sym)]
      allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_hosts).and_return(host_struct)
      allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_folders).and_return([datacenter, vm_folder])

      ws.root

      expect(miq_provision.reload.options[:placement_folder_name]).to eq([vm_folder.id, vm_folder.name])
    end
  end
end
