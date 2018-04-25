describe ServiceRetireTask do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:vm) { FactoryGirl.create(:vm) }
  let(:service) { FactoryGirl.create(:service) }
  let(:miq_request) { FactoryGirl.create(:service_retire_request, :requester => user) }
  let(:miq_request_task) { FactoryGirl.create(:miq_request_task, :miq_request_id => miq_request.id) }
  let(:service_retire_task) { FactoryGirl.create(:service_retire_task, :source => service, :miq_request_task_id => miq_request_task.id, :miq_request_id => miq_request.id, :options => {:src_ids => [service.id] }) }
  let(:reason) { "Why Not?" }
  let(:approver) { FactoryGirl.create(:user_miq_request_approver) }
  let(:zone) { FactoryGirl.create(:zone, :name => "fred") }

  it "should initialize properly" do
    expect(service_retire_task.state).to eq('pending')
    expect(service_retire_task.status).to eq('Ok')
  end

  describe "respond to update_and_notify_parent" do
    context "state queued" do
      it "should not call task_finished" do
        service_retire_task.update_and_notify_parent(:state => "queued", :status => "Ok", :message => "yabadabadoo")

        expect(service_retire_task.message).to eq("yabadabadoo")
      end
    end

    context "state finished" do
      it "should call task_finished" do
        service_retire_task.update_and_notify_parent(:state => "finished", :status => "Ok", :message => "yabadabadoo")

        expect(service_retire_task.status).to eq("Completed")
      end
    end
  end

  describe "#after_request_task_create" do
    context "sans resource" do
      it "doesn't create subtask" do
        service_retire_task.after_request_task_create

        expect(service_retire_task.description).to eq("Service Retire for: #{service.name} - ")
        expect(VmRetireTask.count).to eq(0)
      end
    end

    context "with resource" do
      before do
        allow(MiqServer).to receive(:my_zone).and_return(Zone.seed.name)
        miq_request.approve(approver, reason)
      end

      it "creates subtask" do
        resource = FactoryGirl.create(:service_resource, :resource_type => "VmOrTemplate", :service_id => service.id, :resource_id => vm.id)
        service.service_resources << resource
        service_retire_task.after_request_task_create

        expect(service_retire_task.description).to eq("Service Retire for: #{service.name} - ")
        expect(VmRetireTask.count).to eq(1)
      end
    end
  end

  describe "deliver_to_automate" do
    before do
      allow(MiqServer).to receive(:my_zone).and_return(Zone.seed.name)
      miq_request.approve(approver, reason)
    end

    it "updates the task state to pending" do
      allow(MiqQueue).to receive(:put)
      expect(service_retire_task).to receive(:update_and_notify_parent).with(
        :state   => 'pending',
        :status  => 'Ok',
        :message => 'Automation Starting'
      )
      service_retire_task.deliver_to_automate
    end
  end
end
