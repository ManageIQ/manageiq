describe ServiceRetireTask do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:vm) { FactoryGirl.create(:vm) }
  let(:service) { FactoryGirl.create(:service) }
  let(:miq_request) { FactoryGirl.create(:service_retire_request, :requester => user) }
  let(:service_retire_task) { FactoryGirl.create(:service_retire_task, :source => service, :miq_request => miq_request, :options => {:src_ids => [service.id] }) }
  let(:reason) { "Why Not?" }
  let(:approver) { FactoryGirl.create(:user_miq_request_approver) }
  let(:zone) { FactoryGirl.create(:zone, :name => "fred") }

  shared_context "service_bundle" do
    let(:zone) { FactoryGirl.create(:small_environment) }
    let(:service_c1) { FactoryGirl.create(:service, :service => service) }

    before do
      allow(MiqServer).to receive(:my_server).and_return(zone.miq_servers.first)
      @miq_request = FactoryGirl.create(:service_retire_request, :requester => user)
      @miq_request.approve(approver, reason)
    end
  end

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

    context "bundled service retires all children" do
      include_context "service_bundle"
      let(:vm1) { FactoryGirl.create(:vm_vmware) }
      let(:service_c2) { FactoryGirl.create(:service, :service => service_c1) }

      before do
        service_c1 << vm
        service_c2 << vm1
        service.save
        service_c1.save
        service_c2.save
      end

      it "creates subtask" do
        @service_retire_task = FactoryGirl.create(:service_retire_task, :source => service, :miq_request_task_id => nil, :miq_request_id => @miq_request.id, :options => {:src_ids => [service.id] })
        service.service_resources << FactoryGirl.create(:service_resource, :resource_type => "VmOrTemplate", :service_id => service_c1.id, :resource_id => vm.id)
        service.service_resources << FactoryGirl.create(:service_resource, :resource_type => "VmOrTemplate", :service_id => service_c1.id, :resource_id => vm1.id)
        service.service_resources << FactoryGirl.create(:service_resource, :resource_type => "Service", :service_id => service_c1.id, :resource_id => service_c1.id)
        service.service_resources << FactoryGirl.create(:service_resource, :resource_type => "ServiceTemplate", :service_id => service_c1.id, :resource_id => service_c1.id)

        @service_retire_task.after_request_task_create
        expect(VmRetireTask.count).to eq(2)
        expect(VmRetireTask.all.pluck(:message)).to eq(["Automation Starting", "Automation Starting"])
        expect(ServiceRetireTask.count).to eq(1)
        expect(ServiceRetireRequest.count).to eq(1)
      end

      it "doesn't creates subtask for ServiceTemplates" do
        @service_retire_task = FactoryGirl.create(:service_retire_task, :source => service, :miq_request_task_id => nil, :miq_request_id => @miq_request.id, :options => {:src_ids => [service.id] })
        service.service_resources << FactoryGirl.create(:service_resource, :resource_type => "ServiceTemplate", :service_id => service_c1.id, :resource_id => service_c1.id)

        @service_retire_task.after_request_task_create
        expect(ServiceRetireTask.count).to eq(1)
        expect(ServiceRetireRequest.count).to eq(1)
      end

      it "doesn't creates subtask for service resources whose resources are nil" do
        @service_retire_task = FactoryGirl.create(:service_retire_task, :source => service, :miq_request_task_id => nil, :miq_request_id => @miq_request.id, :options => {:src_ids => [service.id] })
        service.service_resources << FactoryGirl.create(:service_resource, :resource_type => "ServiceTemplate", :service_id => service_c1.id, :resource => nil)

        @service_retire_task.after_request_task_create
        expect(ServiceRetireTask.count).to eq(1)
        expect(ServiceRetireRequest.count).to eq(1)
      end
    end
  end

  describe "deliver_to_automate" do
    before do
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
