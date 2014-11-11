require "spec_helper"

describe AutomationRequest do
  before(:each) do
    MiqServer.stub(:my_zone).and_return("default")
    @zone        = FactoryGirl.create(:zone, :name => "fred")
    User.any_instance.stub(:role).and_return("admin")
    @user        = FactoryGirl.create(:user)
    @approver    = FactoryGirl.create(:user_miq_request_approver)

    @version     = 1
    @ae_instance = "IIII"
    @ae_message  = "MMMM"
    @ae_var1     = "vvvv"
    @ae_var2     = "wwww"
    @ae_var3     = "xxxx"
    @uri_parts   = "instance=#{@ae_instance}|message=#{@ae_message}"
    @parameters  = "var1=#{@ae_var1}|var2=#{@ae_var2}|var3=#{@ae_var3}"
  end

  it ".request_task_class" do
    AutomationRequest.request_task_class.should == AutomationTask
  end

  context ".create_from_ws" do
    it "with empty requester string" do
      ar = AutomationRequest.create_from_ws(@version, @user.userid, @uri_parts, @parameters, "")
      ar.should be_kind_of(AutomationRequest)

      ar.should                           == AutomationRequest.first
      ar.request_state.should             == "pending"
      ar.status.should                    == "Ok"
      ar.approval_state.should            == "pending_approval"
      ar.userid.should                    == @user.userid
      ar.options[:message].should         == @ae_message
      ar.options[:instance_name].should   == @ae_instance
      ar.options[:user_id].should         == @user.id
      ar.options[:attrs][:var1].should    == @ae_var1
      ar.options[:attrs][:var2].should    == @ae_var2
      ar.options[:attrs][:var3].should    == @ae_var3
      ar.options[:attrs][:userid].should  == @user.userid
    end

    it "with requester string overriding userid who is NOT in the database" do
      user_name = 'oleg'
      ar = AutomationRequest.create_from_ws(@version, @user.userid, @uri_parts, @parameters, "user_name=#{user_name}")
      ar.should be_kind_of(AutomationRequest)

      ar.should                           == AutomationRequest.first
      ar.request_state.should             == "pending"
      ar.status.should                    == "Ok"
      ar.approval_state.should            == "pending_approval"
      ar.userid.should                    == user_name
      ar.options[:message].should         == @ae_message
      ar.options[:instance_name].should   == @ae_instance
      ar.options[:user_id].should         be_nil
      ar.options[:attrs][:var1].should    == @ae_var1
      ar.options[:attrs][:var2].should    == @ae_var2
      ar.options[:attrs][:var3].should    == @ae_var3
      ar.options[:attrs][:userid].should  == user_name
    end

    it "with requester string overriding userid who is in the database" do
      ar = AutomationRequest.create_from_ws(@version, @user.userid, @uri_parts, @parameters, "user_name=#{@approver.userid}")
      ar.should be_kind_of(AutomationRequest)

      ar.should                           == AutomationRequest.first
      ar.request_state.should             == "pending"
      ar.status.should                    == "Ok"
      ar.approval_state.should            == "pending_approval"
      ar.userid.should                    == @approver.userid
      ar.options[:message].should         == @ae_message
      ar.options[:instance_name].should   == @ae_instance
      ar.options[:user_id].should         == @approver.id
      ar.options[:attrs][:var1].should    == @ae_var1
      ar.options[:attrs][:var2].should    == @ae_var2
      ar.options[:attrs][:var3].should    == @ae_var3
      ar.options[:attrs][:userid].should  == @approver.userid
    end

    it "with requester string overriding userid AND auto_approval" do
      ar = AutomationRequest.create_from_ws(@version, @user.userid, @uri_parts, @parameters, "user_name=#{@approver.userid}|auto_approve=true")
      ar.should be_kind_of(AutomationRequest)

      ar.should                           == AutomationRequest.first
      ar.request_state.should             == "pending"
      ar.status.should                    == "Ok"
      ar.approval_state.should            == "approved"
      ar.userid.should                    == @approver.userid
      ar.options[:message].should         == @ae_message
      ar.options[:instance_name].should   == @ae_instance
      ar.options[:user_id].should         == @approver.id
      ar.options[:attrs][:var1].should    == @ae_var1
      ar.options[:attrs][:var2].should    == @ae_var2
      ar.options[:attrs][:var3].should    == @ae_var3
      ar.options[:attrs][:userid].should  == @approver.userid
    end
  end

  context "#approve" do
    context "an unapproved request with a single approver" do
      before(:each) do
        @ar = AutomationRequest.create_from_ws(@version, @user.userid, @uri_parts, @parameters, "")
        @reason = "Why Not?"
      end

      it "updates approval_state" do
        @ar.approve(@approver.userid, @reason)
        @ar.reload.approval_state.should == "approved"
      end

      it "calls #call_automate_event_queue('request_approved')" do
        AutomationRequest.any_instance.should_receive(:call_automate_event_queue).with('request_approved').once
        @ar.approve(@approver.userid, @reason)
      end

      it "calls #execute" do
        AutomationRequest.any_instance.should_receive(:execute).once
        @ar.approve(@approver.userid, @reason)
      end

    end
  end

  context "#create_request_tasks" do
    before(:each) do
      @ar = AutomationRequest.create_from_ws(@version, @user.userid, @uri_parts, @parameters, "")
      root = { 'ae_result' => 'ok' }
      ws = double('ws')
      ws.stub(:root => root)
      AutomationRequest.any_instance.stub(:call_automate_event).and_return(ws)

      @ar.create_request_tasks
      @ar.reload
    end

    it "should create AutomationTask" do
      @ar.automation_tasks.length.should == 1
      AutomationTask.count.should == 1
      AutomationTask.first.should == @ar.automation_tasks.first
    end

  end

  context "validate zone" do
    it "zone specified" do
      @parameters  = "miq_zone=#{@zone.name}|var1=#{@ae_var1}|var2=#{@ae_var2}|var3=#{@ae_var3}"
      @ar = AutomationRequest.create_from_ws(@version, @user.userid, @uri_parts, @parameters, "")
      queue = MiqQueue.first
      queue.zone.should eq(@zone.name)
    end

    it "zone not specified" do
      @ar = AutomationRequest.create_from_ws(@version, @user.userid, @uri_parts, @parameters, "")
      queue = MiqQueue.first
      queue.zone.should eq("default")
    end

    it "non existent zone specified" do
      @parameters  = "miq_zone=nothing|var1=#{@ae_var1}|var2=#{@ae_var2}|var3=#{@ae_var3}"
      expect { AutomationRequest.create_from_ws(@version, @user.userid, @uri_parts, @parameters, "") }
        .to raise_error(ArgumentError)
    end

    it "blank zone should result in empty zone" do
      @parameters  = "miq_zone=""|var1=#{@ae_var1}|var2=#{@ae_var2}|var3=#{@ae_var3}"
      @ar = AutomationRequest.create_from_ws(@version, @user.userid, @uri_parts, @parameters, "")
      queue = MiqQueue.first
      queue.zone.should eq(nil)
    end

    it "nil zone should result in empty zone" do
      @parameters  = "miq_zone=|var1=#{@ae_var1}|var2=#{@ae_var2}|var3=#{@ae_var3}"
      @ar = AutomationRequest.create_from_ws(@version, @user.userid, @uri_parts, @parameters, "")
      queue = MiqQueue.first
      queue.zone.should eq(nil)
    end

  end

end
