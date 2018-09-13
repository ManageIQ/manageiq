describe MiqRequest do
  let(:fred)   { FactoryGirl.create(:user_with_group, :name => 'Fred Flintstone', :userid => 'fred',   :email => "fred@example.com") }
  let(:barney) { FactoryGirl.create(:user_with_group, :name => 'Barney Rubble',   :userid => 'barney', :email => "barney@example.com") }

  context "CONSTANTS" do
    it "REQUEST_TYPES" do
      expected_request_types = {
        :MiqProvisionRequest                      => {:template                   => "VM Provision", :clone_to_vm => "VM Clone", :clone_to_template => "VM Publish"},
        :MiqProvisionRequestTemplate              => {:template                   => "VM Provision Template"},
        :MiqProvisionConfiguredSystemRequest      => {:provision_via_foreman      => "#{ui_lookup(:ui_title => 'foreman')} Provision"},
        :VmReconfigureRequest                     => {:vm_reconfigure             => "VM Reconfigure"},
        :VmCloudReconfigureRequest                => {:vm_cloud_reconfigure       => "VM Cloud Reconfigure"},
        :VmMigrateRequest                         => {:vm_migrate                 => "VM Migrate"},
        :VmRetireRequest                          => {:vm_retire                  => "VM Retire"},
        :ServiceRetireRequest                     => {:service_retire             => "Service Retire"},
        :OrchestrationStackRetireRequest          => {:orchestration_stack_retire => "Orchestration Stack Retire"},
        :AutomationRequest                        => {:automation                 => "Automation"},
        :ServiceTemplateProvisionRequest          => {:clone_to_service           => "Service Provision"},
        :ServiceReconfigureRequest                => {:service_reconfigure        => "Service Reconfigure"},
        :PhysicalServerProvisionRequest           => {:provision_physical_server  => "Physical Server Provision"},
        :ServiceTemplateTransformationPlanRequest => {:transformation_plan        => "Transformation Plan"}
      }

      expect(described_class::REQUEST_TYPES).to eq(expected_request_types)
    end
  end

  context "A new request" do
    let(:event_name)   { "hello" }
    let(:miq_request) { FactoryGirl.build(:automation_request, :options => {:src_ids => [1]}) }
    let(:request)      { FactoryGirl.create(:vm_migrate_request, :requester => fred) }
    let(:ems)          { FactoryGirl.create(:ems_vmware) }
    let(:template)     { FactoryGirl.create(:template_vmware, :ext_management_system => ems) }

    it { expect(request).to be_valid }
    describe("#request_type_display") { it { expect(request.request_type_display).to eq("VM Migrate") } }

    it "should not fail when using :select" do
      expect { MiqRequest.select("requester_name").to_a }.to_not raise_error
    end

    context "#set_description" do
      it "should set a description when nil" do
        expect(miq_request.description).to be_nil
        expect(miq_request).to receive(:update_attributes).with(:description => "Automation Task")

        miq_request.set_description
      end

      it "should not set description when one exists" do
        miq_request.description = "test description"
        miq_request.set_description

        expect(miq_request.description).to eq("test description")
      end

      it "should set description when :force => true" do
        miq_request.description = "test description"
        expect(miq_request).to receive(:update_attributes).with(:description => "Automation Task")

        miq_request.set_description(true)
      end
    end

    it ".find_source_id_from_values with :src_ids" do
      src_id_hash = {:src_ids => [101, 102, 103]}
      expect(described_class.send(:find_source_id_from_values, src_id_hash)).to eq(101)
    end

    it "#call_automate_event_queue" do
      zone = FactoryGirl.create(:zone)
      allow(MiqServer).to receive(:my_zone).and_return(zone.name)

      expect(MiqQueue.count).to eq(0)

      request.call_automate_event_queue(event_name)
      msg = MiqQueue.first

      expect(MiqQueue.count).to  eq(1)
      expect(msg.class_name).to  eq(request.class.name)
      expect(msg.instance_id).to eq(request.id)
      expect(msg.method_name).to eq("call_automate_event")
      expect(msg.zone).to        eq(zone.name)
      expect(msg.args).to        eq([event_name])
      expect(msg.msg_timeout).to eq(1.hour)
    end

    context "#call_automate_event" do
      it "successful" do
        expect(MiqAeEvent).to receive(:raise_evm_event).and_return("foo")
        expect(request.call_automate_event(event_name)).to eq("foo")
      end

      it "re-raises exceptions" do
        allow(MiqAeEvent).to receive(:raise_evm_event).and_raise(MiqAeException::AbortInstantiation.new("bogus automate error"))
        expect { request.call_automate_event(event_name) }.to raise_error(MiqAeException::Error, "bogus automate error")
      end
    end

    it "#pending" do
      expect(request).to receive(:call_automate_event_queue).with("request_pending").once

      request.pending
    end

    it "#approval_denied" do
      expect(request).to receive(:call_automate_event_queue).with("request_denied").once

      request.approval_denied

      expect(request.approval_state).to eq('denied')
    end

    context "using Polymorphic Resource" do
      let(:provision_request) { FactoryGirl.create(:miq_provision_request, :requester => fred, :src_vm_id => template.id) }

      it { expect(provision_request.workflow_class).to eq(ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow) }

      it "#workflow" do
        expect(provision_request.workflow({:number_of_vms => 1}, :skip_dialog_load => true))
          .to be_a ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow
      end

      describe("#get_options")          { it { expect(provision_request.get_options).to eq(:number_of_vms => 1) } }
      describe("#request_type")         { it { expect(provision_request.request_type).to eq(provision_request.provision_type) } }
      describe("#request_type_display") { it { expect(provision_request.request_type_display).to eq("VM Provision") } }

      context "#approval_approved" do
        it "not approved" do
          allow(provision_request).to receive(:approved?).and_return(false)

          expect(provision_request.approval_approved).to be_falsey
        end

        it "approved" do
          allow(provision_request).to receive(:approved?).and_return(true)

          expect(provision_request).to receive(:call_automate_event_queue).with("request_approved").once
          expect(provision_request.resource).to receive(:execute).once

          provision_request.approval_approved

          expect(provision_request.approval_state).to eq('approved')
        end
      end

      context "#request_status" do
        context "status nil" do
          it "approval_state approved" do
            provision_request.status = nil
            provision_request.approval_state = 'approved'
            expect(provision_request.request_status).to eq('Unknown')
          end
        end

        context "with status" do
          it "status hello" do
            provision_request.approval_state = 'approved'
            expect(provision_request.request_status).to eq('Ok')
          end

          it "approval_state denied" do
            provision_request.approval_state  = 'denied'
            expect(provision_request.request_status).to eq('Error')
          end

          it "approval_state pending_approval" do
            provision_request.approval_state  = 'pending_approval'
            expect(provision_request.request_status).to eq('Unknown')
          end
        end
      end
    end

    context "using MiqApproval" do
      context "no approvals" do
        it "#build_default_approval" do
          approval = request.build_default_approval

          expect(approval.description).to eq("Default Approval")
          expect(approval.approver).to    be_nil
        end

        it "default values" do
          expect(request.approver).to            be_nil
          expect(request.first_approval).to      be_kind_of(MiqApproval)
          expect(request.reason).to              be_nil
          expect(request.stamped_by).to          be_nil
          expect(request.stamped_on).to          be_nil
          expect(request.v_approved_by).to       be_blank
          expect(request.v_approved_by_email).to be_blank
        end
      end

      context "with user approvals" do
        let(:reason)          { "Why Not?" }
        let(:fred_approval)   { FactoryGirl.create(:miq_approval, :approver => fred, :reason => reason, :stamper => barney, :stamped_on => Time.now) }
        let(:barney_approval) { FactoryGirl.create(:miq_approval, :approver => barney) }

        before { request.miq_approvals = [fred_approval, barney_approval] }

        it "default values" do
          expect(request.approver).to       eq(fred.name)
          expect(request.first_approval).to eq(fred_approval)
          expect(request.reason).to         eq(reason)
          expect(request.stamped_by).to     eq(barney.userid)
          expect(request.stamped_on).to     eq(fred_approval.stamped_on)
        end

        it "#approved? requires all approvals" do
          expect(request).to_not be_approved

          fred_approval.state = 'approved'

          expect(request).to_not be_approved

          barney_approval.state = 'approved'

          expect(request).to     be_approved
        end

        context "#v_approved_by methods" do
          it "with one approval" do
            fred_approval.approve(fred, reason)

            expect(request.v_approved_by).to       eq(fred.name)
            expect(request.v_approved_by_email).to eq(fred.email)
          end

          it "with two approvals" do
            fred_approval.approve(fred, reason)
            barney_approval.approve(barney, reason)

            expect(request.v_approved_by).to       eq("#{fred.name}, #{barney.name}")
            expect(request.v_approved_by_email).to eq("#{fred.email}, #{barney.email}")
          end
        end

        it "#approve" do
          allow(request).to receive(:approved?).and_return(true, false)

          expect(fred_approval).to receive(:approve).once

          2.times { request.approve(fred, reason) }
        end

        it "#deny" do
          expect(fred_approval).to receive(:deny).once

          request.deny(fred, reason)
        end

        describe ".with_reason_like" do
          let(:reason) { %w(abcd abcde cde) }
          subject { described_class.with_reason_like(pattern).count }

          before { request.miq_approvals = approvals }

          ["ab*", "*bc*", "*de"].each do |pattern|
            context "'#{pattern}'" do
              let(:pattern) { pattern }
              it { is_expected.to eq(2) }
            end
          end

          context "integrates well with .created_recently" do
            # when joined with MiqApprovals, there are two `created_on` columns
            let(:pattern) { "*c*" }
            subject { described_class.with_reason_like(pattern).created_recently(days_ago).distinct.count }

            before do
              FactoryGirl.create(:vm_migrate_request, :requester => fred, :created_on => 10.days.ago, :miq_approvals => approvals)
              FactoryGirl.create(:vm_migrate_request, :requester => fred, :created_on => 14.days.ago, :miq_approvals => approvals)
              FactoryGirl.create(:vm_migrate_request, :requester => fred, :created_on => 3.days.ago,  :miq_approvals => approvals)
            end

            {
              7  => 2,
              11 => 3,
              15 => 4
            }.each do |days, count|
              context "filtering #{days} ago" do
                let(:days_ago) { days }
                it { is_expected.to eq(count) }
              end
            end
          end

          def approvals
            reason.collect do |r|
              FactoryGirl.create(:miq_approval, :approver => fred, :reason => r, :stamper => barney, :stamped_on => Time.now.utc)
            end
          end
        end
      end
    end

    it "#deny" do
      allow_any_instance_of(MiqApproval).to receive_messages(:authorized? => true)
      allow(MiqServer).to receive_messages(:my_zone => "default")

      provision_request = FactoryGirl.create(:miq_provision_request, :requester => fred, :src_vm_id => template.id)

      provision_request.deny(fred, "Why Not?")

      provision_request.miq_approvals.each { |approval| expect(approval.state).to eq('denied') }

      provision_request.reload

      expect(provision_request.status).to         eq('Denied')
      expect(provision_request.request_state).to  eq('finished')
      expect(provision_request.approval_state).to eq('denied')
    end
  end

  context '#execute' do
    shared_examples_for "#calls create_request_tasks with the proper role" do
      it "runs successfully" do
        expect(request).to receive(:approved?).and_return(true)
        expect(MiqQueue.count).to eq(0)

        request.execute
        expect(MiqQueue.count).to eq(1)
        expect(MiqQueue.first.role).to eq(role)
      end
    end

    context 'Service provisioning' do
      let(:request) { FactoryGirl.create(:service_template_provision_request, :approval_state => 'approved', :requester => fred) }
      let(:role)    { 'automate' }

      context "uses the automate role" do
        it_behaves_like "#calls create_request_tasks with the proper role"
      end
    end

    context 'VM provisioning' do
      let(:template) { FactoryGirl.create(:template_vmware, :ext_management_system => FactoryGirl.create(:ems_vmware_with_authentication)) }
      let(:request)  { FactoryGirl.build(:miq_provision_request, :requester => fred, :src_vm_id => template.id).tap(&:valid?) }
      let(:role)     { 'ems_operations' }

      context "uses the ems_operations role" do
        it_behaves_like "#calls create_request_tasks with the proper role"
      end
    end
  end

  context '#post_create_request_tasks' do
    context 'VM provisioning' do
      before do
        ae_workspace = double("ae_workspace")
        allow(ae_workspace).to receive(:root).and_return("test_vm")
        allow(MiqAeEngine).to receive(:resolve_automation_object).and_return(ae_workspace)
      end

      let(:description) { 'my original information' }
      let(:template)    { FactoryGirl.create(:template_vmware, :ext_management_system => FactoryGirl.create(:ems_vmware_with_authentication)) }
      let(:request)     { FactoryGirl.build(:miq_provision_request, :requester => fred, :description => description, :src_vm_id => template.id).tap(&:valid?) }

      it 'with 1 task' do
        request.options[:src_vm_id] = template.id
        request.create_request_task(template.id)
        request.post_create_request_tasks
        expect(request.description).to_not eq(description)
      end

      it 'with 1 task having a Denied status reset to ok for the resulting request_task' do
        request.options[:src_vm_id] = template.id
        request.status = 'Denied'
        new_request = request.create_request_task(template.id)
        expect(new_request.status).to eq 'Ok'
      end

      it 'with 0 tasks' do
        allow(request).to receive(:requested_task_idx).and_return([])
        request.post_create_request_tasks
        expect(request.description).to eq(description)
      end

      it 'with >1 tasks' do
        allow(request).to receive(:requested_task_idx).and_return([1, 2])
        request.post_create_request_tasks
        expect(request.description).to eq(description)
      end

      it '#clean_up_keys_for_request_task' do
        # The db stores 'state' as 'request_state' Pulling out that value to allow the raw arrays to match
        removable_keys = MiqRequest::REQUEST_UNIQUE_KEYS - ['state']
        expect(request.attributes.keys & removable_keys).to match_array removable_keys
        cleaned_attribs = request.send(:clean_up_keys_for_request_task)
        expect(cleaned_attribs).to_not match_array(removable_keys)
      end

      it '#clean_up_keys_for_request_task removes options user_message' do
        request.update_attributes!(:options => {:user_message => 'doesntmatter'})
        cleaned_attribs = request.send(:clean_up_keys_for_request_task)
        expect(cleaned_attribs["options"]).to_not include(:user_message)
      end
    end

    it 'non VM provisioning' do
      description = 'Service Request'
      request = FactoryGirl.create(:service_template_provision_request, :description => description, :requester => fred)
      request.post_create_request_tasks
      expect(request.description).to eq(description)
    end
  end

  context '#workflow' do
    let(:provision_request) do
      FactoryGirl.create(:miq_provision_request,
                         :requester => fred,
                         :src_vm_id => template.id,
                         :options => {:src_vm_id => template.id})
    end
    let(:ems)          { FactoryGirl.create(:ems_vmware) }
    let(:template)     { FactoryGirl.create(:template_vmware, :ext_management_system => ems) }
    let(:host) { double('Host', :id => 1, :name => 'my_host') }

    it "calls password_helper when a block is passed in" do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow).to receive(:password_helper).twice
      provision_request.workflow({}, {:allowed_hosts => [host], :skip_dialog_load => true}) { |_x| 'test' }
    end

    it "returns the allowed tags" do
      FactoryGirl.create(:miq_dialog,
                         :name        => "miq_provision_dialogs",
                         :dialog_type => MiqProvisionWorkflow)

      FactoryGirl.create(:classification_department_with_tags)

      tag = Classification.where(:description => 'Department', :parent_id => 0).includes(:tag).first
      provision_request.add_tag(tag.name, tag.children.first.name)

      expected = [a_hash_including(:children)]
      expect(provision_request.v_allowed_tags).to match(expected)
    end
  end

  context '#create_request_task' do
    let(:ems)      { FactoryGirl.create(:ems_vmware_with_authentication) }
    let(:template) { FactoryGirl.create(:template_vmware, :ext_management_system => ems) }
    let(:request)  do
      FactoryGirl.create(:miq_provision_request, :requester => fred, :options => @options, :source => template)
    end

    before do
      allow(MiqRegion).to receive(:my_region).and_return(FactoryGirl.create(:miq_region))
      ae_workspace = double("ae_workspace")
      allow(ae_workspace).to receive(:root).and_return("test_vm")
      allow(MiqAeEngine).to receive(:resolve_automation_object).and_return(ae_workspace)

      @options = {
        :src_vm_id     => template.id,
        :number_of_vms => 3,
      }
    end

    it '1 task' do
      task = request.create_request_task(1)
      expect(task.type).to  eq(template.ext_management_system.class.provision_class('_vmware').name)
      expect(task.state).to eq('pending')
      expect(request.request_state).to eq('pending')
    end

    it 'multiple tasks' do
      task = nil
      (1..2).each do |idx|
        task = request.create_request_task(idx)
        expect(task.state).to eq('pending')
        request.miq_request_tasks << task
      end

      task.update_and_notify_parent(:state => 'queued', :message => 'State Machine Initializing')
      task = request.create_request_task(3)

      expect(task.state).to eq('pending')
      expect(request.request_state).to eq('active')
    end
  end

  context ".class_from_request_data" do
    it "with a valid request_type" do
      expect(described_class.class_from_request_data(:request_type => "template")).to eq(MiqProvisionRequest)
    end

    it "with a invalid request_type" do
      expect { described_class.class_from_request_data(:request_type => "abc") }.to raise_error("Invalid request_type")
    end

    it "without a request_type" do
      expect { described_class.class_from_request_data({}) }.to raise_error("Invalid request_type")
    end
  end

  context "#get_user" do
    let(:root_tenant) { Tenant.seed }
    let(:tenant1)     { FactoryGirl.create(:tenant, :parent => root_tenant) }
    let(:group1)      { FactoryGirl.create(:miq_group, :description => 'Group 1', :tenant => root_tenant) }
    let(:group2)      { FactoryGirl.create(:miq_group, :description => 'Group 2', :tenant => tenant1) }
    let(:user)        { FactoryGirl.create(:user, :miq_groups => [group1, group2], :current_group => group1) }

    it "takes the requester group" do
      request = FactoryGirl.create(:miq_provision_request, :requester => user, :options => {:requester_group => group2.description})
      expect(user.current_group).to eq(group1)
      expect(request.get_user.current_group).to eq(group2)
    end

    it "stays with user's current group" do
      request = FactoryGirl.create(:miq_provision_request, :requester => user)
      expect(user.current_group).to eq(group1)
      expect(request.get_user.current_group).to eq(group1)
    end
  end

  context "#update_request" do
    before do
      allow(MiqServer).to receive(:my_zone).and_return("New York")
    end

    let(:request) do
      FactoryGirl.create(:miq_provision_request,
                         :requester => fred,
                         :options   => {:a => "1"})
    end

    it "user_message" do
      msg = "Yabba Dabba Doo"
      expect(request).not_to receive(:after_update_options)
      request.update_request({:user_message => msg}, fred)

      request.reload
      expect(request.options[:user_message]).to eq(msg)
      expect(request.message).to eq(msg)
    end

    it "truncates long messages" do
      msg = "Yabba Dabba Doo" * 30
      expect(request).not_to receive(:after_update_options)
      request.update_request({:user_message => msg}, fred)

      request.reload
      expect(request.options[:user_message].length).to eq(255)
      expect(request.message.length).to eq(255)
    end

    it "non user_message should call after_update_options" do
      expect(request).to receive(:after_update_options)
      request.update_request({:abc => 1}, fred)

      expect(request.options[:abc]).to eq(1)
    end
  end

  context "retire request source classes" do
    let(:vm_retire_request)      { FactoryGirl.create(:vm_retire_request, :requester => fred) }
    let(:service_retire_request) { FactoryGirl.create(:service_retire_request, :requester => fred) }
    let(:orch_stack_request)     { FactoryGirl.create(:orchestration_stack_retire_request, :requester => fred) }

    it "gets the right source class names" do
      expect(vm_retire_request.class::SOURCE_CLASS_NAME).to eq('Vm')
      expect(service_retire_request.class::SOURCE_CLASS_NAME).to eq('Service')
      expect(orch_stack_request.class::SOURCE_CLASS_NAME).to eq('OrchestrationStack')
    end
  end
end
