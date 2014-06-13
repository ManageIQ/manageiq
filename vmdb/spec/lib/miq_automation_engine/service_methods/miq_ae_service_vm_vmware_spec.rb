require 'spec_helper'

module MiqAeServiceVmVmwareSpec
  describe MiqAeMethodService::MiqAeServiceUser do
    let(:vm)         { FactoryGirl.create(:vm_vmware) }
    let(:service_vm) { MiqAeMethodService::MiqAeServiceVmVmware.find(vm.id) }

    before do
      Vm.any_instance.stub(:my_zone).and_return('default')
      @base_queue_options = {
        :class_name  => vm.class.name,
        :instance_id => vm.id,
        :zone        => 'default',
        :role        => 'ems_operations'
      }
    end

    it "#set_number_of_cpus" do
      MiqQueue.should_receive(:put).with(@base_queue_options.merge(
        :method_name => 'set_number_of_cpus',
        :args        => [1])
      )

      service_vm.set_number_of_cpus(1)
    end

    it "#set_memory" do
      MiqQueue.should_receive(:put).with(@base_queue_options.merge(
        :method_name => 'set_memory',
        :args        => [100])
      )

      service_vm.set_memory(100)
    end

    it "#add_disk" do
      MiqQueue.should_receive(:put).with(@base_queue_options.merge(
        :method_name => 'add_disk',
        :args        => ['disk_1', 100])
      )

      service_vm.add_disk('disk_1', 100)
    end
  end
end
