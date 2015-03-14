require "spec_helper"

describe MiqRequest do
  let(:fred)   { FactoryGirl.create(:user, :name => 'Fred Flintstone', :userid => 'fred') }
  let(:barney) { FactoryGirl.create(:user, :name => 'Barney Rubble',   :userid => 'barney') }

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
      let(:template) { FactoryGirl.create(:template_vmware) }
      let(:request)  { FactoryGirl.create(:miq_provision_request, :userid => fred.userid, :src_vm_id => template.id).create_request }

      it { expect(request.workflow_class).to eq(MiqProvisionVmwareWorkflow) }
      describe("#get_options")          { it { expect(request.get_options).to eq(:number_of_vms => 1) } }
      describe("#request_type")         { it { expect(request.request_type).to eq(request.provision_type) } }
      describe("#request_type_display") { it { expect(request.request_type_display).to eq("VM Provision") } }

      context "#approval_approved" do
        it "not approved" do
          request.stub(:approved?).and_return(false)

          expect(request.approval_approved).to be_false
        end

        it "approved" do
          request.stub(:approved?).and_return(true)

          request.should_receive(:call_automate_event_queue).with("request_approved").once
          request.resource.should_receive(:execute).once

          request.approval_approved

          expect(request.approval_state).to eq('approved')
        end
      end

      context "#request_status" do
        context "status nil" do
          it "approval_state approved" do
            request.status = nil
            request.approval_state = 'approved'
            expect(request.request_status).to eq('Unknown')
          end
        end

        context "with status" do
          it "status hello" do
            request.approval_state = 'approved'
            expect(request.request_status).to eq('Ok')
          end

          it "approval_state denied" do
            request.approval_state  = 'denied'
            expect(request.request_status).to eq('Error')
          end

          it "approval_state pending_approval" do
            request.approval_state  = 'pending_approval'
            expect(request.request_status).to eq('Unknown')
          end
        end
      end
    end

    context "using MiqApproval" do
      before do
        @reason         = "Why Not?"
        @wilma          = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'wilma',  :email => 'wilma@bedrock.gov')
        @barney         = FactoryGirl.create(:user, :name => 'Barney Rubble',    :userid => 'barney', :email => 'barney@bedrock.gov')
        @betty          = FactoryGirl.create(:user, :name => 'Betty Rubble',     :userid => 'betty',  :email => 'betty@bedrock.gov')
        @wilma_approval = FactoryGirl.create(:miq_approval, :approver => @wilma)
        @betty_approval = FactoryGirl.create(:miq_approval, :approver => @betty)
        request.miq_approvals = [@wilma_approval, @betty_approval]
      end

      it "#approved?" do
        request.approved?.should be_false
        @wilma_approval.state = 'approved'
        request.approved?.should be_false
        @betty_approval.state = 'approved'
        request.approved?.should be_true
      end

      it "#build_default_approval" do
        approval = request.build_default_approval
        approval.description.should == "Default Approval"
        approval.approver.should    be_nil
      end

      it "#v_approved_by" do
        @wilma_approval.approve(@wilma.userid, @reason)
        request.v_approved_by.should == "#{@wilma.name}"
        @betty_approval.approve(@betty.userid, @reason)
        request.v_approved_by.should == "#{@wilma.name}, #{@betty.name}"
        request.miq_approvals = []
        request.v_approved_by.should == ""
      end

      it "#v_approved_by_email" do
        @wilma_approval.approve(@wilma.userid, @reason)
        request.v_approved_by_email.should == "#{@wilma.email}"
        @betty_approval.approve(@betty.userid, @reason)
        request.v_approved_by_email.should == "#{@wilma.email}, #{@betty.email}"
        request.miq_approvals = []
        request.v_approved_by_email.should == ""
      end

      it "#approve" do
        request.stub(:approved?).and_return(true, false)
        @wilma_approval.should_receive(:approve).once
        2.times { request.approve(@wilma.userid, @reason) }
      end

      it "#deny" do
        @wilma_approval.should_receive(:deny).once
        request.deny(@wilma.userid, @reason)
      end

      it "#first_approval" do
        request.first_approval.should == @wilma_approval
        request.miq_approvals = []
        request.first_approval.should be_kind_of(MiqApproval)
      end

      it "#stamped_by" do
        @wilma_approval.stamper = @betty
        request.stamped_by.should == @betty.userid
        request.miq_approvals = []
        request.stamped_by.should be_nil
      end

      it "#stamped_on" do
        now = Time.now
        @wilma_approval.stamped_on = now
        request.stamped_on.should == now
        request.miq_approvals = []
        request.stamped_on.should be_nil
      end

      it "#reason" do
        @wilma_approval.reason = @reason
        request.reason.should == @reason
        request.miq_approvals = []
        request.reason.should be_nil
      end

      it "#approver" do
        request.approver.should == @wilma.name
        request.miq_approvals = []
        request.approver.should be_nil
      end

      # TODO: This is IDENTICAL to #approver method
      it "#approver_role" do
        request.approver.should == @wilma.name
        request.miq_approvals = []
        request.approver.should be_nil
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
