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
    let(:handoff) { {:key => [vm.class.base_class.name, vm.id], :task_id => task.id, :taken => false, :not_queued => false} }

    before { EvmSpecHelper.local_miq_server }
    after  { Thread.current[:policy_prevent_task] = nil }

    it "puts the task on the raw_start message and only once" do
      Thread.current[:policy_prevent_task] = handoff
      vm.start_queue
      vm.stop_queue

      raw_start = MiqQueue.find_by(:method_name => "raw_start")
      expect(raw_start.miq_task_id).to eq(task.id)
      expect(raw_start.miq_callback).to include(:class_name => "MiqTask", :method_name => :queue_callback, :instance_id => task.id, :args => ["Finished"])
      expect(MiqQueue.find_by(:method_name => "raw_stop").miq_task_id).to be_nil
      expect(handoff[:taken]).to be(true)
    end

    it "ignores a task handed over for another record" do
      Thread.current[:policy_prevent_task] = handoff.merge(:key => [vm.class.base_class.name, vm.id + 1])
      vm.start_queue

      expect(MiqQueue.find_by(:method_name => "raw_start").miq_task_id).to be_nil
    end

    it "lets an explicit miq_task_id win and does not take the task" do
      Thread.current[:policy_prevent_task] = handoff
      vm.run_command_via_queue("raw_start", :miq_task_id => 0)

      expect(MiqQueue.find_by(:method_name => "raw_start").miq_task_id).to eq(0)
      expect(handoff[:taken]).to be(false)
    end

    it "does not take the task when no message was created (maintenance zone)" do
      handoff
      allow(Zone).to receive(:maintenance?).and_return(true)
      Thread.current[:policy_prevent_task] = handoff
      vm.start_queue

      expect(MiqQueue.where(:method_name => "raw_start")).to be_empty
      expect(handoff).to include(:taken => false, :not_queued => true)
    end

    it "finishes the task with an error from the callback when no message was created (maintenance zone)" do
      vm
      allow(Zone).to receive(:maintenance?).and_return(true)

      vm.check_policy_prevent_task_callback(task.id, :start_queue, "ok", "msg", nil)

      expect(MiqQueue.where(:method_name => "raw_start")).to be_empty
      task.reload
      expect([task.state, task.status, task.message]).to eq(["Finished", "Error", "queue message not created"])
      expect(Thread.current[:policy_prevent_task]).to be_nil
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
