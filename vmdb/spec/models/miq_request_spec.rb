require "spec_helper"

describe MiqRequest do
  context "Class Methods" do
    before(:each) do
      @fred          = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      @barney        = FactoryGirl.create(:user, :name => 'Barney Rubble',    :userid => 'barney')
      @requests_for_fred   = []
      @requests_for_barney = []
      @requests_for_fred   << FactoryGirl.create(:miq_request, :requester => @fred)
      @requests_for_fred   << FactoryGirl.create(:miq_request, :requester => @fred)
      @requests_for_barney << FactoryGirl.create(:miq_request, :requester => @barney)
    end

    it "#requests_for_userid" do
      MiqRequest.requests_for_userid(@barney.userid).should have_same_elements(@requests_for_barney)
      MiqRequest.requests_for_userid(@fred.userid).should   have_same_elements(@requests_for_fred)
    end

    it "#all_requesters" do
      expected_hash = {}
      [@fred, @barney].each { |user| expected_hash[user.id] = user.name }
      MiqRequest.all_requesters.should == expected_hash

      expected_hash[@barney.id] = "#{@barney.name} (no longer exists)"
      @barney.destroy
      MiqRequest.all_requesters.should == expected_hash

      old_name = @fred.name
      new_name = "Fred Flintstone, Sr."
      @fred.update_attributes(:name => new_name)
      expected_hash[@fred.id] = old_name
      MiqRequest.all_requesters.should == expected_hash
      @fred.update_attributes(:name => old_name)

      expected_hash[@fred.id] = "#{@fred.name} (no longer exists)"
      @fred.destroy
      MiqRequest.all_requesters.should == expected_hash
    end
  end

  context "A new request" do
    before(:each) do
      @fred          = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      @approver_role = UiTaskSet.create(:name => "approver", :description => "Approver")
      @request       = FactoryGirl.create(:miq_request, :requester => @fred)
    end

    it "should validate" do
      @request.should be_valid
    end

    it "should not fail when using :select" do
      lambda { MiqRequest.find(:all,  :select=>"requester_name") }.should_not raise_error
    end

    it "#call_automate_event_queue" do
      zone_name = "New York"
      MiqServer.stub(:my_zone).and_return(zone_name)
      event_name = "hello"
      MiqQueue.count.should == 0
      @request.call_automate_event_queue(event_name)
      MiqQueue.count.should == 1
      msg = MiqQueue.first
      msg.class_name.should  == @request.class.name
      msg.instance_id.should == @request.id
      msg.method_name.should == "call_automate_event"
      msg.zone.should        == zone_name
      msg.args.should        == [event_name]
      msg.msg_timeout.should == 1.hour
    end

    it "#call_automate_event" do
      event_name = "hello"
      ws         = "foo"
      err_msg    = "bogus automate error"
      MiqAeEvent.stub(:raise_evm_event).and_return(ws)
      @request.call_automate_event(event_name).should == ws

      MiqAeEvent.stub(:raise_evm_event).and_raise(MiqAeException::AbortInstantiation.new(err_msg))
      lambda { @request.call_automate_event(event_name) }.should raise_error(MiqAeException::Error, err_msg)
    end

    it "#pending" do
      @request.should_receive(:call_automate_event_queue).with("request_pending").once
      @request.pending
    end

    it "#approval_denied" do
      @request.should_receive(:call_automate_event_queue).with("request_denied").once
      @request.approval_denied
      @request.approval_state.should == 'denied'
    end

    it "#requester_userid" do
      @request.requester_userid.should == @fred.userid
    end

    context "using Polymorphic Resource" do
      before(:each) do
        @template = FactoryGirl.create(:template_vmware)
        @resource = FactoryGirl.create(:miq_provision_request, :userid => @fred.userid, :src_vm_id => @template.id)
        @resource.create_request
        @request = @resource
      end

      it "#approval_approved" do
        @request.stub(:approved?).and_return(false)
        @request.approval_approved.should be_false

        @request.stub(:approved?).and_return(true)
        @request.should_receive(:call_automate_event_queue).with("request_approved").once
        @request.resource.should_receive(:execute).once
        @request.approval_approved
        @request.approval_state.should == 'approved'
      end

      it "#request_status" do
        @request.approval_state  = 'approved'
        @request.resource.status = 'hello'
        @request.request_status.should == @request.resource.status
        @request.resource.status = nil
        @request.request_status.should == 'Unknown'
        @request.approval_state  = 'denied'
        @request.request_status.should == 'Error'
        @request.approval_state  = 'pending_approval'
        @request.request_status.should == 'Unknown'
      end

      it "#message" do
        @request.message.should == @resource.message
      end

      it "#get_options" do
        @resource.options = { :foo => 1, :bar => 2 }
        @request.get_options.should == @resource.options
      end

      it "#status" do
        @request.status.should == @resource.status
      end

      it "#request_type" do
        @request.request_type.should == @resource.provision_type
      end

      it "#request_type_display" do
        @request.request_type_display.should == "VM Provision"
      end

      it "#workflow_class" do
        @request.workflow_class.should == MiqProvisionVmwareWorkflow
      end
    end

    context "using MiqApproval" do
      before(:each) do
        @reason         = "Why Not?"
        @wilma          = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'wilma',  :email => 'wilma@bedrock.gov')
        @barney         = FactoryGirl.create(:user, :name => 'Barney Rubble',    :userid => 'barney', :email => 'barney@bedrock.gov')
        @betty          = FactoryGirl.create(:user, :name => 'Betty Rubble',     :userid => 'betty',  :email => 'betty@bedrock.gov')
        @wilma_approval = FactoryGirl.create(:miq_approval, :approver => @wilma)
        @betty_approval = FactoryGirl.create(:miq_approval, :approver => @betty)
        @request.miq_approvals = [@wilma_approval, @betty_approval]
      end

      it "#approved?" do
        @request.approved?.should be_false
        @wilma_approval.state = 'approved'
        @request.approved?.should be_false
        @betty_approval.state = 'approved'
        @request.approved?.should be_true
      end

      it "#build_default_approval" do
        approval = @request.build_default_approval
        approval.description.should == "Default Approval"
        approval.approver.should    be_nil
      end

      it "#v_approved_by" do
        @wilma_approval.approve(@wilma.userid, @reason)
        @request.v_approved_by.should == "#{@wilma.name}"
        @betty_approval.approve(@betty.userid, @reason)
        @request.v_approved_by.should == "#{@wilma.name}, #{@betty.name}"
        @request.miq_approvals = []
        @request.v_approved_by.should == ""
      end

      it "#v_approved_by_email" do
        @wilma_approval.approve(@wilma.userid, @reason)
        @request.v_approved_by_email.should == "#{@wilma.email}"
        @betty_approval.approve(@betty.userid, @reason)
        @request.v_approved_by_email.should == "#{@wilma.email}, #{@betty.email}"
        @request.miq_approvals = []
        @request.v_approved_by_email.should == ""
      end

      it "#approve" do
        @request.stub(:approved?).and_return(true, false)
        @wilma_approval.should_receive(:approve).once
        2.times { @request.approve(@wilma.userid, @reason) }
      end

      it "#deny" do
        @wilma_approval.should_receive(:deny).once
        @request.deny(@wilma.userid, @reason)
      end

      it "#first_approval" do
        @request.first_approval.should == @wilma_approval
        @request.miq_approvals = []
        @request.first_approval.should be_kind_of(MiqApproval)
      end

      it "#stamped_by" do
        @wilma_approval.stamper = @betty
        @request.stamped_by.should == @betty.userid
        @request.miq_approvals = []
        @request.stamped_by.should be_nil
      end

      it "#stamped_on" do
        now = Time.now
        @wilma_approval.stamped_on = now
        @request.stamped_on.should == now
        @request.miq_approvals = []
        @request.stamped_on.should be_nil
      end

      it "#reason" do
        @wilma_approval.reason = @reason
        @request.reason.should == @reason
        @request.miq_approvals = []
        @request.reason.should be_nil
      end

      it "#approver" do
        @request.approver.should == @wilma.name
        @request.miq_approvals = []
        @request.approver.should be_nil
      end

      # TODO: This is IDENTICAL to #approver method
      it "#approver_role" do
        @request.approver.should == @wilma.name
        @request.miq_approvals = []
        @request.approver.should be_nil
      end

    end

    it "#deny" do
      MiqServer.stub(:my_zone).and_return("default")
      vm_template = FactoryGirl.create(:template_vmware, :name => "template1")
      pr = FactoryGirl.create(:miq_provision_request, :userid => @fred.userid, :src_vm_id => vm_template.id )
      MiqApproval.any_instance.stub(:authorized?).and_return(true)

      reason   = "Why Not?"
      pr.deny(@fred.userid, reason)

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
