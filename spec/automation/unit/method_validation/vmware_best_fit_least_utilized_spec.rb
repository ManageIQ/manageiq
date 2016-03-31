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
  let(:vm_template) { FactoryGirl.create(:template_vmware, :ext_management_system => ems) }
  let(:ws) do
    MiqAeEngine.instantiate("/System/Request/Call_Instance_With_Message?" \
                            "namespace=Infrastructure/VM/Provisioning&class=Placement" \
                            "&instance=default&message=vmware&" \
                            "MiqProvision::miq_provision=#{miq_provision.id}", user)
  end

  context "Auto placement" do
    let(:storages) { 4.times.collect { |r| FactoryGirl.create(:storage, :free_space => 1000 * (r + 1)) } }

    let(:ro_storage) { FactoryGirl.create(:storage, :free_space => 10000) }

    let(:vms) { 5.times.collect { FactoryGirl.create(:vm_vmware) } }

    # host1 has two small  storages and 2 vms
    # host2 has two larger storages and 3 vms
    # host3 has one larger read-only datastore and one smaller writable datastore
    let(:host1) { FactoryGirl.create(:host_vmware, :storages => storages[0..1], :vms => vms[2..3], :ext_management_system => ems) }
    let(:host2) { FactoryGirl.create(:host_vmware, :storages => storages[0..1], :vms => vms[2..4], :ext_management_system => ems) }
    let(:host3) { FactoryGirl.create(:host_vmware, :storages => [ro_storage, storages[2]], :vms => vms[2..4], :ext_management_system => ems) }

    let(:host_struct) do
      [MiqHashStruct.new(:id => host1.id, :evm_object_class => host1.class.base_class.name.to_sym),
       MiqHashStruct.new(:id => host2.id, :evm_object_class => host2.class.base_class.name.to_sym)]
    end

    context "hosts with a cluster" do
      before do
        host1.ems_cluster = ems_cluster
        host2.ems_cluster = ems_cluster
        datacenter.with_relationship_type("ems_metadata") { datacenter.add_child(ems_cluster) }
        HostStorage.where(:host_id => host3.id, :storage_id => ro_storage.id).update(:read_only => true)
      end

      it "selects a host with fewer vms and a storage with more free space" do
        allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_hosts).and_return(host_struct)
        allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_storages).and_return(storages)

        ws.root
        miq_provision.reload
        expect(miq_provision.options[:placement_host_name]).to eq([host1.id, host1.name])
        expect(miq_provision.options[:placement_ds_name]).to   eq([host1.storages[1].id, host1.storages[1].name])
      end

      it "selects largest storage that is writable" do
        allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_hosts).and_return([host3])
        allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_storages).and_return(host3.storages)

        ws.root
        miq_provision.reload

        # host3.storages[0] is larger but read-only, so it should select host3.storages[1]
        expect(miq_provision.options[:placement_ds_name]).to eq([host3.storages[1].id, host3.storages[1].name])
      end
    end

    context "hosts without a cluster" do
      before do
        datacenter.with_relationship_type("ems_metadata") { datacenter.add_child(host1); datacenter.add_child(host2) }
      end

      it "selects a host with fewer vms and a storage with more free space" do
        allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_hosts).and_return(host_struct)
        allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_storages).and_return(storages)

        ws.root
        miq_provision.reload
        expect(miq_provision.options[:placement_host_name]).to eq([host1.id, host1.name])
        expect(miq_provision.options[:placement_ds_name]).to   eq([host1.storages[1].id, host1.storages[1].name])
      end
    end
  end
end
