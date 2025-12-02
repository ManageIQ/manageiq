RSpec.describe VmRetireTask do
  let(:user) { FactoryBot.create(:user_with_group) }
  let(:vm) { FactoryBot.create(:vm, :raw_power_state => power_state) }
  let!(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:miq_request) { FactoryBot.create(:vm_retire_request, :requester => user) }
  let(:vm_retire_task) { FactoryBot.create(:vm_retire_task, :source => vm, :miq_request => miq_request, :options => {:src_ids => [vm.id]}) }
  let(:approver) { FactoryBot.create(:user_miq_request_approver) }
  let(:power_state) { "unknown" }

  # power_state= is a private and set by the subclass, set directly here so
  # that we can use the generic VM factory
  before { vm.send(:power_state=, power_state) }

  it "should initialize properly" do
    expect(vm_retire_task).to have_attributes(:state => 'pending', :status => 'Ok')
  end

  describe "#after_request_task_create" do
    it "should set the task description" do
      vm_retire_task.after_request_task_create
      expect(vm_retire_task.description).to eq("VM Retire for: #{vm.name}")
    end
  end

  describe "deliver_to_automate" do
    before do
      allow(MiqServer).to receive(:my_zone).and_return(Zone.seed.name)
      miq_request.approve(approver, "why not??")
    end

    it "updates the task state to pending" do
      expect(vm_retire_task).to receive(:update_and_notify_parent).with(
        :state   => 'pending',
        :status  => 'Ok',
        :message => 'Automation Starting'
      )
      vm_retire_task.deliver_to_automate
    end
  end

  describe "#check_vm_power_state" do
    context "with a running vm" do
      let(:power_state) { "on" }

      it "calls stop and signals poll_vm_stopped" do
        expect(vm).to receive(:stop)
        vm_retire_task.signal(:check_vm_power_state)
        expect(vm_retire_task.phase).to eq("poll_vm_stopped")
      end
    end

    context "with a powered off vm" do
      let(:power_state) { "off" }

      it "signals start_retirement" do
        expect(vm_retire_task).to receive(:start_retirement)
        vm_retire_task.signal(:check_vm_power_state)
      end
    end
  end

  describe "#poll_vm_stopped" do
    context "with a running vm" do
      let(:power_state) { "on" }

      it "requeues poll_vm_stopped" do
        vm_retire_task.signal(:poll_vm_stopped)
        expect(vm_retire_task.phase).to eq("poll_vm_stopped")
        expect(MiqQueue.first).to have_attributes(:class_name => described_class.name, :method_name => "poll_vm_stopped")
      end
    end

    context "with a stopped vm" do
      let(:power_state) { "off" }

      it "signals start_retirement" do
        expect(vm_retire_task).to receive(:start_retirement)
        vm_retire_task.signal(:poll_vm_stopped)
      end
    end
  end

  describe "#start_retirement" do
    before do
      NotificationType.seed
    end

    it "creates a vm_retiring notification" do
      expect(vm_retire_task).to receive(:finish_retirement)
      vm_retire_task.signal(:start_retirement)

      vm_retiring_notifications = Notification.of_type(:vm_retiring)
      expect(vm_retiring_notifications.count).to eq(1)
      expect(vm_retiring_notifications.first.subject).to eq(vm)
    end

    it "start the vm retirement process" do
      expect(vm_retire_task).to receive(:finish_retirement)
      vm_retire_task.signal(:start_retirement)
      expect(vm.reload.retirement_state).to eq("retiring")
    end

    context "with a retired vm" do
      let(:vm) { FactoryBot.create(:vm, :retirement_state => "retired", :retired => true) }

      it "fails the retirement" do
        vm_retire_task.signal(:start_retirement)
        expect(vm_retire_task.reload).to have_attributes(
          :state   => "finished",
          :status  => "Error",
          :message => "VM already retired"
        )
      end
    end

    context "with a retiring vm" do
      let(:vm) { FactoryBot.create(:vm, :retirement_state => "retiring") }

      it "fails the retirement" do
        vm_retire_task.signal(:start_retirement)
        expect(vm_retire_task.reload).to have_attributes(
          :state   => "finished",
          :status  => "Error",
          :message => "VM already in the process of being retired"
        )
      end
    end
  end

  describe "#finish_retirement" do
    before do
      NotificationType.seed
      vm.start_retirement
    end

    it "creates a vm_retired notification" do
      vm_retire_task.signal(:finish_retirement)

      vm_retired_notifications = Notification.of_type(:vm_retired)
      expect(vm_retired_notifications.count).to eq(1)
      expect(vm_retired_notifications.first.subject).to eq(vm)
    end

    it "retires the VM" do
      vm_retire_task.signal(:finish_retirement)

      vm.reload
      expect(vm.retirement_state).to eq("retired")
      expect(vm.retired?).to be_truthy
    end
  end
end
