module MiqAeServiceManageIQ_Providers_Redhat_InfraManager_VmSpec
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_Redhat_InfraManager_Vm do
    let(:vm)         { FactoryGirl.create(:vm_redhat) }
    let(:service_vm) { MiqAeMethodService::MiqAeServiceManageIQ_Providers_Redhat_InfraManager_Vm.find(vm.id) }

    before do
      allow(MiqServer).to receive(:my_zone).and_return('default')
      @base_queue_options = {
        :class_name  => vm.class.name,
        :instance_id => vm.id,
        :zone        => 'default',
        :role        => 'ems_operations',
        :task_id     => nil
      }
    end

    it "#add_disk" do
      service_vm.add_disk('disk_1', 100, :interface => "IDE", :bootable => true)

      expect(MiqQueue.first).to have_attributes(
        @base_queue_options.merge(
          :method_name => 'add_disk',
          :args        => ['disk_1', 100, {:interface => "IDE", :bootable => true}])
      )
    end
  end
end
