RSpec.describe VmOrTemplate::Operations::Power do
  let(:ems) { FactoryBot.create(:ems_infra) }
  let(:vm)  { FactoryBot.create(:vm_infra, :ext_management_system => ems) }

  context "#start_queue" do
    it "queues a raw_start method" do
      vm.start_queue
      expect(MiqQueue.first).to have_attributes(
        :class_name  => vm.class.name,
        :method_name => "raw_start"
      )
    end
  end

  context "stop_queue" do
    it "queues a raw_stop method" do
      vm.stop_queue
      expect(MiqQueue.first).to have_attributes(
        :class_name  => vm.class.name,
        :method_name => "raw_stop"
      )
    end
  end

  context "suspend_queue" do
    it "queues a raw_stop method" do
      vm.suspend_queue
      expect(MiqQueue.first).to have_attributes(
        :class_name  => vm.class.name,
        :method_name => "raw_suspend"
      )
    end
  end

  context "shelve_offload_queue" do
    it "queues a raw_stop method" do
      vm.shelve_offload_queue
      expect(MiqQueue.first).to have_attributes(
        :class_name  => vm.class.name,
        :method_name => "raw_shelve_offload"
      )
    end
  end

  context "pause_queue" do
    it "queues a raw_stop method" do
      vm.pause_queue
      expect(MiqQueue.first).to have_attributes(
        :class_name  => vm.class.name,
        :method_name => "raw_pause"
      )
    end
  end
end
