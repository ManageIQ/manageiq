RSpec.describe ServiceRetireTask do
  let(:user) { FactoryBot.create(:user_with_group) }
  let(:vm) { FactoryBot.create(:vm) }
  let(:service) { FactoryBot.create(:service, :lifecycle_state => 'provisioned') }
  let(:miq_request) { FactoryBot.create(:service_retire_request, :requester => user, :source => service) }
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

  shared_examples_for "no_remove_resource" do
    it "creates 1 service retire subtask" do
      ap_service.add_resource!(FactoryBot.create(:vm_vmware))
      ap_service_retire_task.after_request_task_create

      expect(ap_service_retire_task.description).to eq("Service Retire for: #{ap_service.name}")
      expect(ServiceRetireTask.count).to eq(1)
      expect(VmRetireTask.count).to eq(0)
    end
  end

  shared_examples_for "yes_remove_resource" do
    it "creates 1 service retire subtask and 1 vm retire subtask" do
      ap_service.add_resource!(FactoryBot.create(:vm_vmware))
      ap_service_retire_task.after_request_task_create

      expect(ap_service_retire_task.description).to eq("Service Retire for: #{ap_service.name}")
      expect(ServiceRetireTask.count).to eq(1)
      expect(VmRetireTask.count).to eq(1)
    end
  end

  describe "#after_request_task_create" do
    context "sans resource" do
      it "doesn't create subtask" do
        service_retire_task.after_request_task_create

        expect(service_retire_task.description).to eq("Service Retire for: #{service.name}")
        expect(VmRetireTask.count).to eq(0)
        expect(ServiceRetireTask.count).to eq(1)
      end
    end

    context "with resource" do
      before do
        MiqRegion.seed
        allow(MiqServer).to receive(:my_zone).and_return(Zone.seed.name)
        miq_request.approve(approver, reason)
      end

      it "doesn't create service retire subtask for unprov'd service" do
        service.add_resource!(FactoryBot.create(:service_orchestration))
        service_retire_task.after_request_task_create

        expect(service_retire_task.description).to eq("Service Retire for: #{service.name}")
        expect(ServiceRetireTask.count).to eq(1)
      end

      it "creates service retire subtask" do
        service.add_resource!(FactoryBot.create(:service_orchestration, :lifecycle_state => 'provisioned'))
        service_retire_task.after_request_task_create

        expect(service_retire_task.description).to eq("Service Retire for: #{service.name}")
        expect(ServiceRetireTask.count).to eq(2)
      end

      context "ansible playbook service" do
        context "no_with_playbook" do
          let(:ap_service) { FactoryBot.create(:service_ansible_playbook, :options => {:config_info => {:retirement => {:remove_resources => "no_with_playbook"} }}) }
          let(:ap_service_retire_task) { FactoryBot.create(:service_retire_task, :source => ap_service, :miq_request => miq_request, :options => {:src_ids => [ap_service.id] }) }

          it_behaves_like "no_remove_resource"
        end

        context "no_without_playbook" do
          let(:ap_service) { FactoryBot.create(:service_ansible_playbook, :options => {:config_info => {:retirement => {:remove_resources => "no_without_playbook"} }}) }
          let(:ap_service_retire_task) { FactoryBot.create(:service_retire_task, :source => ap_service, :miq_request => miq_request, :options => {:src_ids => [ap_service.id] }) }

          it_behaves_like "no_remove_resource"
        end

        context "yes_with_playbook" do
          let(:ap_service) { FactoryBot.create(:service_ansible_playbook, :options => {:config_info => {:retirement => {:remove_resources => "yes_with_playbook"} }}) }
          let(:ap_service_retire_task) { FactoryBot.create(:service_retire_task, :source => ap_service, :miq_request => miq_request, :options => {:src_ids => [ap_service.id] }) }

          it_behaves_like "yes_remove_resource"
        end

        context "yes_without_playbook" do
          let(:ap_service) { FactoryBot.create(:service_ansible_playbook, :options => {:config_info => {:retirement => {:remove_resources => "yes_without_playbook"} }}) }
          let(:ap_service_retire_task) { FactoryBot.create(:service_retire_task, :source => ap_service, :miq_request => miq_request, :options => {:src_ids => [ap_service.id] }) }

          it_behaves_like "yes_remove_resource"
        end
      end

      it "creates service retire subtask" do
        service.add_resource!(FactoryBot.create(:service, :lifecycle_state => 'provisioned'))
        service_retire_task.after_request_task_create

        expect(service_retire_task.description).to eq("Service Retire for: #{service.name}")
        expect(ServiceRetireTask.count).to eq(2)
      end

      it "doesn't create service retire subtask for unprovisioned service" do
        service.add_resource!(FactoryBot.create(:service))
        service_retire_task.after_request_task_create

        expect(service_retire_task.description).to eq("Service Retire for: #{service.name}")
        expect(ServiceRetireTask.count).to eq(1)
      end

      it "creates stack retire subtask" do
        service.add_resource!(FactoryBot.create(:orchestration_stack))
        service_retire_task.after_request_task_create

        expect(service_retire_task.description).to eq("Service Retire for: #{service.name}")
        expect(OrchestrationStackRetireTask.count).to eq(1)
        expect(ServiceRetireTask.count).to eq(1)
      end

      it "doesn't create subtask for miq_provision_request_template" do
        admin = FactoryBot.create(:user_admin)
        vm_template = FactoryBot.create(:vm_openstack, :ext_management_system => FactoryBot.create(:ext_management_system))
        service.add_resource!(FactoryBot.create(:miq_provision_request_template, :requester => admin, :src_vm_id => vm_template.id))
        service_retire_task.after_request_task_create

        expect(service_retire_task.description).to eq("Service Retire for: #{service.name}")
        expect(MiqRetireTask.count).to eq(1)
        expect(ServiceRetireTask.count).to eq(1)
      end

      it "creates vm retire subtask" do
        service.add_resource!(FactoryBot.create(:vm_openstack))
        service_retire_task.after_request_task_create

        expect(service_retire_task.description).to eq("Service Retire for: #{service.name}")
        expect(VmRetireTask.count).to eq(1)
        expect(ServiceRetireTask.count).to eq(1)
      end

      it "does not create vm retire subtask for retired vm" do
        service.add_resource!(FactoryBot.create(:vm_openstack, :retired => true))
        service_retire_task.after_request_task_create

        expect(service_retire_task.description).to eq("Service Retire for: #{service.name}")
        expect(VmRetireTask.count).to eq(0)
        expect(ServiceRetireTask.count).to eq(1)
      end

      context "multiple service retirement" do
        it "creates multiple retire subtasks" do
          s1 = FactoryBot.create(:service)
          s2 = FactoryBot.create(:service)
          s1.add_resource!(FactoryBot.create(:vm_openstack))
          s2.add_resource!(FactoryBot.create(:vm_openstack))

          service_retire_task1 = FactoryBot.create(:service_retire_task, :source => s1, :miq_request => miq_request, :options => {:src_ids => [s1.id, s2.id] })
          service_retire_task1.after_request_task_create

          expect(VmRetireTask.count).to eq(2)
        end
      end
    end

    describe "#self.get_description" do
      it "returns a description based upon the source service name" do
        expect(ServiceRetireTask.get_description(miq_request)).to eq("Service Retire for: #{service.name}")
      end
    end

    context "bundled service retires all valid children" do
      let(:service_c1) { FactoryBot.create(:service, :lifecycle_state => 'provisioned') }
      let(:service_c2) { FactoryBot.create(:service) }

      before do
        service.add_resource!(service_c1)
        service.add_resource!(service_c2)
        service.add_resource!(FactoryBot.create(:service_template))
        @miq_request = FactoryBot.create(:service_retire_request, :requester => user)
        @miq_request.approve(approver, reason)
        @service_retire_task = FactoryBot.create(:service_retire_task, :source => service, :miq_request => @miq_request, :options => {:src_ids => [service.id] })
      end

      it "creates subtask for provisioned services but not templates" do
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
