describe ServiceRetireTask do
  let(:user) { FactoryBot.create(:user_with_group) }
  let(:vm) { FactoryBot.create(:vm) }
  let(:service) { FactoryBot.create(:service) }
  let(:miq_request) { FactoryBot.create(:service_retire_request, :requester => user) }
  let(:service_retire_task) { FactoryBot.create(:service_retire_task, :source => service, :miq_request => miq_request, :options => {:src_ids => [service.id] }) }
  let(:reason) { "Why Not?" }
  let(:approver) { FactoryBot.create(:user_miq_request_approver) }
  let(:zone) { FactoryBot.create(:zone, :name => "fred") }

  it "should initialize properly" do
    expect(service_retire_task).to have_attributes(:state => 'pending', :status => 'Ok')
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

        expect(service_retire_task.status).to eq("Ok")
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
        MiqRegion.seed
        allow(MiqServer).to receive(:my_zone).and_return(Zone.seed.name)
        miq_request.approve(approver, reason)
      end

      context "resource lacks type" do
        it "creates service retire subtask" do
          resource = FactoryBot.create(:service_resource, :resource_type => nil, :service_id => service.id, :resource_id => vm.id)
          service.service_resources << resource
          service_retire_task.after_request_task_create

          expect(service_retire_task.description).to eq("Service Retire for: #{service.name} - ")
          expect(ServiceRetireTask.count).to eq(1)
        end
      end

      context "resource has type" do
        it "creates vm retire subtask" do
          resource = FactoryBot.create(:service_resource, :resource_type => "VmOrTemplate", :service_id => service.id, :resource_id => vm.id)
          service.service_resources << resource
          service_retire_task.after_request_task_create

          expect(service_retire_task.description).to eq("Service Retire for: #{service.name} - ")
          expect(VmRetireTask.count).to eq(1)
        end
      end
    end

    context "bundled service retires all children" do
      let(:service_c1) { FactoryBot.create(:service) }

      before do
        service.add_resource!(service_c1)
        service.add_resource!(FactoryBot.create(:service_template))
        @miq_request = FactoryBot.create(:service_retire_request, :requester => user)
        @miq_request.approve(approver, reason)
        @service_retire_task = FactoryBot.create(:service_retire_task, :source => service, :miq_request => @miq_request, :options => {:src_ids => [service.id] })
      end

      it "creates subtask for services but not templates" do
        @service_retire_task.after_request_task_create

        expect(ServiceRetireTask.count).to eq(2)
        expect(ServiceRetireRequest.count).to eq(1)
      end

      it "doesn't creates subtask for ServiceTemplates" do
        @service_retire_task.after_request_task_create

        expect(ServiceRetireTask.count).to eq(2)
      end
    end
  end

  describe "deliver_to_automate" do
    before do
      MiqRegion.seed
      allow(MiqServer).to receive(:my_zone).and_return(Zone.seed.name)
      miq_request.approve(approver, reason)
    end

    it "updates the task state to pending" do
      expect(service_retire_task).to receive(:update_and_notify_parent).with(
        :state   => 'pending',
        :status  => 'Ok',
        :message => 'Automation Starting'
      )
      service_retire_task.deliver_to_automate
    end
  end
end
