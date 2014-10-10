require "spec_helper"

describe VmdbwsController, :apis => true do

  before(:each) do
    @guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(@guid)

    @zone       = FactoryGirl.create(:zone)
    @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
    MiqServer.stub(:my_server).and_return(@miq_server)

    super_role   = FactoryGirl.create(:ui_task_set, :name => 'super_administrator', :description => 'Super Administrator')
    @admin       = FactoryGirl.create(:user, :name => 'admin',            :userid => 'admin',    :ui_task_set_id => super_role.id)
    @user        = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred',     :ui_task_set_id => super_role.id)
    @approver    = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver', :ui_task_set_id => super_role.id)
    UiTaskSet.stub(:find_by_name).and_return(@approver)

    ::UiConstants
    @controller = VmdbwsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller.stub(:authenticate).and_return(true)

    @controller.instance_variable_set(:@username, "admin")

    @version             = "1.0"
    @ae_instance         = "IIII"
    @ae_message          = "MMMM"
    @ae_var1             = "vvvv"
    @ae_var2             = "wwww"
    @ae_var3             = "xxxx"
    @uri_parts           = "instance=#{@ae_instance}|message=#{@ae_message}"
    @automate_parameters = "var1=#{@ae_var1}|var2=#{@ae_var2}|var3=#{@ae_var3}"
    @requester           = ""
  end

  it "#CreateAutomationRequest" do
    AutomationRequest.count.should == 0
    req_id = invoke(:CreateAutomationRequest, @version, @uri_parts, @automate_parameters, @requester)
    req_id.should be_an_instance_of(String)
    AutomationRequest.count.should == 1
    AutomationRequest.first.id.should == req_id.to_i
  end

  context "#GetAutomationRequest" do
    it "raises error when matching request is not found" do
      req_id = '7'
      lambda do
        invoke(:GetAutomationRequest, req_id)
      end.should raise_error(RuntimeError, "AutomationRequest with ID=<#{req_id} (String)> was not found")
    end

    context "when matching AutomationRequest exists" do
      before(:each) do
        @ar = FactoryGirl.create(:automation_request)
      end

      it "returns proper ProxyAutomationRequest object" do
        req = invoke(:GetAutomationRequest, @ar.id)
        req.should be_an_instance_of(VmdbwsSupport::ProxyAutomationRequest)
        req.approval_state.should == @ar.approval_state
        req.request_state.should  == @ar.request_state
        req.status.should         == @ar.status
        req.requester_name.should == @ar.requester_name
        req.userid.should         == @ar.userid
        req.automation_tasks.should be_kind_of(Array)
        req.automation_tasks.should be_empty
      end

      context "with an AutomationTask" do
        before(:each) do
          @attrs   = { :var1 => @ae_var1, :var2 => @ae_var2, :var3 => @ae_var3, :userid => @user.userid }
          @options = { :attrs => @attrs, :instance_name => @instance, :message => @message, :user_id => @user.id, :delivered_on => Time.now.utc.to_s }
          @at = FactoryGirl.create(:automation_task, :state => 'pending', :status => 'Ok', :userid => @user.userid, :options => @options)
          @ar.automation_tasks << @at
          @ar.save!
        end

        it "returns proper ProxyAutomationRequest object" do
          req = invoke(:GetAutomationRequest, @ar.id)
          req.should be_an_instance_of(VmdbwsSupport::ProxyAutomationRequest)
          req.approval_state.should == @ar.approval_state
          req.request_state.should  == @ar.request_state
          req.status.should         == @ar.status
          req.requester_name.should == @ar.requester_name
          req.userid.should         == @ar.userid
          req.automation_tasks.should be_kind_of(Array)
          req.automation_tasks.length.should == 1
          task = req.automation_tasks.first
          task.should be_an_instance_of(VmdbwsSupport::AutomationTaskSummary)
          task.id.to_i.should == @at.id
        end
      end
    end
  end

  context "#GetAutomationTask" do
    it "raises error when matching task is not found" do
      req_id = '7'
      lambda do
        invoke(:GetAutomationTask, req_id)
      end.should raise_error(RuntimeError, "AutomationTask with ID=<#{req_id} (String)> was not found")
    end

    context "when matching AutomationTask exists" do
      before(:each) do
        @attrs   = { :var1 => @ae_var1, :var2 => @ae_var2, :var3 => @ae_var3, :userid => @user.userid }
        @options = { :attrs => @attrs, :instance_name => @instance, :message => @message, :user_id => @user.id, :delivered_on => Time.now.utc.to_s }
        @at = FactoryGirl.create(:automation_task, :state => 'pending', :status => 'Ok', :userid => @user.userid, :options => @options)
        @ar = FactoryGirl.create(:automation_request)
        @ar.automation_tasks << @at
        @ar.save!
      end

      it "returns proper ProxyAutomationTask object" do
        task = invoke(:GetAutomationTask, @at.id)
        task.should be_an_instance_of(VmdbwsSupport::ProxyAutomationTask)
        task.status.should == @at.status
        task.state.should  == @at.state
        task.userid.should == @at.userid
        task.automation_request.should be_an_instance_of(VmdbwsSupport::AutomationRequestSummary)
        task.automation_request.id.to_i.should == @ar.id
      end
    end
  end

end
