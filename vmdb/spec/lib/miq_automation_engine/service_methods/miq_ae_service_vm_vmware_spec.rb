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
        :role        => 'ems_operations',
        :task_id     => nil
      }

      $_miq_worker_current_msg = FactoryGirl.build(:miq_queue, :task_id => '1234')
    end

    after do
      $_miq_worker_current_msg = nil
    end

    it "#set_number_of_cpus" do
      service_vm.set_number_of_cpus(1)

      MiqQueue.first.should have_attributes(
        @base_queue_options.merge(
          :method_name => 'set_number_of_cpus',
          :args        => [1])
      )
    end

    it "#set_memory" do
      service_vm.set_memory(100)

      MiqQueue.first.should have_attributes(
        @base_queue_options.merge(
          :method_name => 'set_memory',
          :args        => [100])
      )
    end

    it "#add_disk" do
      service_vm.add_disk('disk_1', 100)

      MiqQueue.first.should have_attributes(
        @base_queue_options.merge(
          :method_name => 'add_disk',
          :args        => ['disk_1', 100])
      )
    end

    it "#remove_from_disk async"do
      service_vm.remove_from_disk(false)

      MiqQueue.first.should have_attributes(
        @base_queue_options.merge(
          :method_name => 'vm_destroy',
          :args        => [])
      )
    end
  end
end
