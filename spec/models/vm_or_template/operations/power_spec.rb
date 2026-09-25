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

  context "#start_queue with a task handed over by check_policy_prevent" do
    let(:task) { FactoryBot.create(:miq_task) }

    before { EvmSpecHelper.local_miq_server }

    it "puts the task on the raw_start message only" do
      vm.start_queue(:miq_task_id => task.id)
      vm.stop_queue

      raw_start = MiqQueue.find_by(:method_name => "raw_start")
      expect(raw_start.miq_task_id).to eq(task.id)
      expect(raw_start.miq_callback).to include(:class_name => "MiqTask", :method_name => :queue_callback, :instance_id => task.id, :args => ["Finished"])
      expect(MiqQueue.find_by(:method_name => "raw_stop").miq_task_id).to be_nil
    end

    it "creates no message in a maintenance zone" do
      vm
      allow(Zone).to receive(:maintenance?).and_return(true)

      expect(vm.start_queue(:miq_task_id => task.id)).to be_nil
      expect(MiqQueue.where(:method_name => "raw_start")).to be_empty
    end

    it "finishes the task with an error from the callback when no message was created (maintenance zone)" do
      vm
      allow(Zone).to receive(:maintenance?).and_return(true)

      vm.check_policy_prevent_task_callback(task.id, :start_queue, "ok", "msg", nil)

      expect(MiqQueue.where(:method_name => "raw_start")).to be_empty
      task.reload
      expect([task.state, task.status, task.message]).to eq(["Finished", "Error", "queue message not created"])
    end

    it "hands the task to the raw_create_snapshot message with its args" do
      vm.check_policy_prevent_task_callback(task.id, :create_snapshot_queue, "name", "desc", false, "ok", "msg", nil)

      msg = MiqQueue.find_by(:method_name => "raw_create_snapshot")
      expect(msg.args).to eq(["name", "desc", false])
      expect(msg.miq_task_id).to eq(task.id)
      expect(task.reload.state).not_to eq("Finished")
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
