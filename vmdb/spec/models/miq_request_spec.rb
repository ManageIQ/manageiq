require "spec_helper"

describe MiqRequest do
  let(:fred)   { FactoryGirl.create(:user, :name => 'Fred Flintstone', :userid => 'fred',   :email => "fred@example.com") }
  let(:barney) { FactoryGirl.create(:user, :name => 'Barney Rubble',   :userid => 'barney', :email => "barney@example.com") }

  context "CONSTANTS" do
    it "REQUEST_TYPES" do
      expected_request_types = {
        :MiqProvisionRequest             => {:template            => "VM Provision", :clone_to_vm => "VM Clone", :clone_to_template => "VM Publish"},
        :MiqProvisionRequestTemplate     => {:template            => "VM Provision Template"},
        :MiqHostProvisionRequest         => {:host_pxe_install    => "Host Provision"},
        :VmReconfigureRequest            => {:vm_reconfigure      => "VM Reconfigure"},
        :VmMigrateRequest                => {:vm_migrate          => "VM Migrate"},
        :AutomationRequest               => {:automation          => "Automation"},
        :ServiceTemplateProvisionRequest => {:clone_to_service    => "Service Provision"},
        :ServiceReconfigureRequest       => {:service_reconfigure => "Service Reconfigure"},
      }

      expect(described_class::REQUEST_TYPES).to eq(expected_request_types)
    end
  end

  context "Class Methods" do
    before do
      @requests_for_fred   = [FactoryGirl.create(:miq_request, :requester => fred), FactoryGirl.create(:miq_request, :requester => fred)]
      @requests_for_barney = [FactoryGirl.create(:miq_request, :requester => barney)]
    end

    it "#requests_for_userid" do
      expect(MiqRequest.requests_for_userid(barney.userid)).to match_array(@requests_for_barney)
      expect(MiqRequest.requests_for_userid(fred.userid)).to   match_array(@requests_for_fred)
    end

    it "#all_requesters" do
      expected_hash = [fred, barney].each_with_object({}) { |user, hash| hash[user.id] = user.name }

      expect(MiqRequest.all_requesters).to eq(expected_hash)

      expected_hash[barney.id] = "#{barney.name} (no longer exists)"
      barney.destroy

      expect(MiqRequest.all_requesters).to eq(expected_hash)

      old_name = expected_hash[fred.id] = fred.name
      fred.update_attributes(:name => "Fred Flintstone, Sr.")

      expect(MiqRequest.all_requesters).to eq(expected_hash)

      fred.update_attributes(:name => old_name)

      expected_hash[fred.id] = "#{fred.name} (no longer exists)"
      fred.destroy

      expect(MiqRequest.all_requesters).to eq(expected_hash)
    end
  end

  context "A new request" do
    let(:event_name) { "hello" }
    let(:request)    { FactoryGirl.create(:miq_request, :requester => fred) }

    it { expect(request).to be_valid }
    describe("#request_type_display") { it { expect(request.request_type_display).to eq("Unknown") } }
    describe("#requester_userid")     { it { expect(request.requester_userid).to eq(fred.userid) } }

    it "should not fail when using :select" do
      expect { MiqRequest.find(:all, :select => "requester_name") }.to_not raise_error
    end

    it "#call_automate_event_queue" do
      zone_name  = "New York"

      MiqServer.stub(:my_zone).and_return(zone_name)

      expect(MiqQueue.count).to eq(0)

      request.call_automate_event_queue(event_name)
      msg = MiqQueue.first

      expect(MiqQueue.count).to  eq(1)
      expect(msg.class_name).to  eq(request.class.name)
      expect(msg.instance_id).to eq(request.id)
      expect(msg.method_name).to eq("call_automate_event")
      expect(msg.zone).to        eq(zone_name)
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
      let(:template)          { FactoryGirl.create(:template_vmware) }
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
      MiqServer.stub(:my_zone).and_return("default")
      vm_template = FactoryGirl.create(:template_vmware, :name => "template1")
      pr = FactoryGirl.create(:miq_provision_request, :userid => fred.userid, :src_vm_id => vm_template.id)
      MiqApproval.any_instance.stub(:authorized?).and_return(true)

      reason   = "Why Not?"
      pr.deny(fred.userid, reason)

      pr.miq_approvals.each do |approval|
        approval.state.should == 'denied'
      end

      pr.reload
      pr.status.should == 'Denied'
      pr.request_state.should == 'finished'
      pr.approval_state.should == 'denied'
    end

  end

end
