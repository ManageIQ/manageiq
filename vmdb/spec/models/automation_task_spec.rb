require "spec_helper"

describe AutomationTask do
  before(:each) do
    MiqServer.stub(:my_zone).and_return("default")
    User.any_instance.stub(:role).and_return("admin")
    @user        = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
    @approver    = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')
    UiTaskSet.stub(:find_by_name).and_return(@approver)

    @ae_instance = "IIII"
    @ae_message  = "MMMM"
    @ae_var1     = "vvvv"
    @ae_var2     = "wwww"
    @ae_var3     = "xxxx"

    @attrs   = { :var1 => @ae_var1, :var2 => @ae_var2, :var3 => @ae_var3, :userid => @user.userid }
    @options = { :attrs => @attrs, :instance => @instance, :message => @message, :user_id => @user.id, :delivered_on => Time.now.utc.to_s }
    @at = FactoryGirl.create(:automation_task, :state => 'pending', :status => 'Ok', :userid => @user.userid, :options => @options)
    @ar = FactoryGirl.create(:automation_request)
    @ar.automation_tasks << @at
    @ar.save!
  end

  it "#execute" do
    MiqAeEngine.should_receive(:deliver).once
    @at.execute
    @ar.reload.message.should == "#{AutomationRequest::TASK_DESCRIPTION} initiated"
  end
end
