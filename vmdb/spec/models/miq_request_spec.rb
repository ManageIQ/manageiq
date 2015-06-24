require "spec_helper"

describe MiqRequest do
  let(:fred)   { FactoryGirl.create(:user, :name => 'Fred Flintstone', :userid => 'fred',   :email => "fred@example.com") }
  let(:barney) { FactoryGirl.create(:user, :name => 'Barney Rubble',   :userid => 'barney', :email => "barney@example.com") }

  context "CONSTANTS" do
    it "REQUEST_TYPES" do
      expected_request_types = {
        :MiqProvisionRequest                 => {:template              => "VM Provision", :clone_to_vm => "VM Clone", :clone_to_template => "VM Publish"},
        :MiqProvisionRequestTemplate         => {:template              => "VM Provision Template"},
        :MiqHostProvisionRequest             => {:host_pxe_install      => "Host Provision"},
        :MiqProvisionConfiguredSystemRequest => {:provision_via_foreman => "#{ui_lookup(:ui_title => 'foreman')} Provision"},
        :VmReconfigureRequest                => {:vm_reconfigure        => "VM Reconfigure"},
        :VmMigrateRequest                    => {:vm_migrate            => "VM Migrate"},
        :AutomationRequest                   => {:automation            => "Automation"},
        :ServiceTemplateProvisionRequest     => {:clone_to_service      => "Service Provision"},
        :ServiceReconfigureRequest           => {:service_reconfigure   => "Service Reconfigure"},
      }

      expect(described_class::REQUEST_TYPES).to eq(expected_request_types)
    end
  end

  context "A new request" do
    let(:event_name)   { "hello" }
    let(:host_request) { FactoryGirl.build(:miq_host_provision_request, :options => {:src_host_ids => [1]}) }
    let(:request)      { FactoryGirl.create(:vm_migrate_request, :userid => fred.userid) }
    let(:template)     { FactoryGirl.create(:template_vmware) }

    it { expect(request).to be_valid }
    describe("#request_type_display") { it { expect(request.request_type_display).to eq("VM Migrate") } }

    it "should not fail when using :select" do
      expect { MiqRequest.select("requester_name").to_a }.to_not raise_error
    end

    context "#set_description" do
      it "should set a description when nil" do
        expect(host_request.description).to be_nil
        host_request.should_receive(:update_attributes).with(:description => "PXE install on [] from image []")

        host_request.set_description
      end

      it "should not set description when one exists" do
        host_request.description = "test description"
        host_request.set_description

        expect(host_request.description).to eq("test description")
      end

      it "should set description when :force => true" do
        host_request.description = "test description"
        host_request.should_receive(:update_attributes).with(:description => "PXE install on [] from image []")

        host_request.set_description(true)
      end
    end

    it "#call_automate_event_queue" do
      MiqServer.stub(:my_zone).and_return("New York")

      expect(MiqQueue.count).to eq(0)

      request.call_automate_event_queue(event_name)
      msg = MiqQueue.first

      expect(MiqQueue.count).to  eq(1)
      expect(msg.class_name).to  eq(request.class.name)
      expect(msg.instance_id).to eq(request.id)
      expect(msg.method_name).to eq("call_automate_event")
      expect(msg.zone).to        eq("New York")
      expect(msg.args).to        eq([event_name])
      expect(msg.msg_timeout).to eq(1.hour)
    end

    context "#call_automate_event" do
      it "successful" do
        MiqAeEvent.stub(:raise_evm_event).and_return("foo")

        expect(request.call_automate_event(event_name)).to eq("foo")
      end

      it "re-raises exceptions" do
        MiqAeEvent.stub(:raise_evm_event).and_raise(MiqAeException::AbortInstantiation.new("bogus automate error"))

        expect { request.call_automate_event(event_name) }.to raise_error(MiqAeException::Error, "bogus automate error")
      end
    end

    it "#pending" do
      request.should_receive(:call_automate_event_queue).with("request_pending").once

      request.pending
    end

    it "#approval_denied" do
      request.should_receive(:call_automate_event_queue).with("request_denied").once

      request.approval_denied

      expect(request.approval_state).to eq('denied')
    end

    context "using Polymorphic Resource" do
      let(:provision_request) { FactoryGirl.create(:miq_provision_request, :userid => fred.userid, :src_vm_id => template.id).create_request }

      it { expect(provision_request.workflow_class).to eq(MiqProvisionVmwareWorkflow) }
      describe("#get_options")          { it { expect(provision_request.get_options).to eq(:number_of_vms => 1) } }
      describe("#request_type")         { it { expect(provision_request.request_type).to eq(provision_request.provision_type) } }
      describe("#request_type_display") { it { expect(provision_request.request_type_display).to eq("VM Provision") } }

      context "#approval_approved" do
        it "not approved" do
          provision_request.stub(:approved?).and_return(false)

          expect(provision_request.approval_approved).to be_false
        end

        it "approved" do
          provision_request.stub(:approved?).and_return(true)

          provision_request.should_receive(:call_automate_event_queue).with("request_approved").once
          provision_request.resource.should_receive(:execute).once

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
            fred_approval.approve(fred.userid, reason)

            expect(request.v_approved_by).to       eq(fred.name)
            expect(request.v_approved_by_email).to eq(fred.email)
          end

          it "with two approvals" do
            fred_approval.approve(fred.userid, reason)
            barney_approval.approve(barney.userid, reason)

            expect(request.v_approved_by).to       eq("#{fred.name}, #{barney.name}")
            expect(request.v_approved_by_email).to eq("#{fred.email}, #{barney.email}")
          end
        end

        it "#approve" do
          request.stub(:approved?).and_return(true, false)

          fred_approval.should_receive(:approve).once

          2.times { request.approve(fred.userid, reason) }
        end

        it "#deny" do
          fred_approval.should_receive(:deny).once

          request.deny(fred.userid, reason)
        end
      end
    end

    it "#deny" do
      MiqApproval.any_instance.stub(:authorized? => true)
      MiqServer.stub(:my_zone => "default")

      provision_request = FactoryGirl.create(:miq_provision_request, :userid => fred.userid, :src_vm_id => template.id)

      provision_request.deny(fred.userid, "Why Not?")

      provision_request.miq_approvals.each { |approval| expect(approval.state).to eq('denied') }

      provision_request.reload

      expect(provision_request.status).to         eq('Denied')
      expect(provision_request.request_state).to  eq('finished')
      expect(provision_request.approval_state).to eq('denied')
    end
  end

  context '#post_create_request_tasks' do
    context 'VM provisioning' do
      let(:description) { 'my original information' }
      let(:template)    { FactoryGirl.create(:template_vmware, :ext_management_system => FactoryGirl.create(:ems_vmware_with_authentication)) }
      let(:request)     { FactoryGirl.build(:miq_provision_request, :userid => fred.userid, :description => description, :src_vm_id => template.id) }

      it 'with 1 task' do
        request.options[:src_vm_id] = template.id
        request.create_request_task(template.id)
        request.post_create_request_tasks
        expect(request.description).to_not eq(description)
      end

      it 'with 0 tasks' do
        request.stub(:requested_task_idx).and_return([])
        request.post_create_request_tasks
        expect(request.description).to eq(description)
      end

      it 'with >1 tasks' do
        request.stub(:requested_task_idx).and_return([1, 2])
        request.post_create_request_tasks
        expect(request.description).to eq(description)
      end
    end

    it 'non VM provisioning' do
      description = 'Service Request'
      request   = FactoryGirl.create(:service_template_provision_request, :description => description, :userid => fred.userid)
      request.post_create_request_tasks
      expect(request.description).to eq(description)
    end
  end
end
