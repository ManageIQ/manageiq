require 'spec_helper'

describe "Orchestration provision Method Validation" do
  let(:miq_request_task)      { FactoryGirl.create(:miq_request_task, :destination => service_orchestration, :miq_request => request) }
  let(:request)               { FactoryGirl.create(:service_template_provision_request, :requester => user) }
  let(:service_orchestration) { FactoryGirl.create(:service_orchestration) }
  let(:user)                  { FactoryGirl.create(:user_with_group) }
  let(:ws)                    { MiqAeEngine.instantiate("/Cloud/Orchestration/Provisioning/StateMachines/Methods/Provision?MiqRequestTask::service_template_provision_task=#{miq_request_task.id}", user) }

  it "provisions a stack through the service" do
    ServiceOrchestration.any_instance.should_receive(:deploy_orchestration_stack)
    ws
  end

  it "catches the error at stack provisioning" do
    ServiceOrchestration.any_instance.stub(:deploy_orchestration_stack) { raise "test failure" }
    ws.root['ae_result'].should == "error"
    ws.root['ae_reason'].should == "test failure"
    request.reload.message.should == "test failure"
  end

  it "truncates the error message exceeding 255 character limits" do
    long_error = 't' * 300
    ServiceOrchestration.any_instance.stub(:deploy_orchestration_stack) { raise long_error }
    ws.root['ae_result'].should == "error"
    ws.root['ae_reason'].should == long_error
    request.reload.message.should == 't' * 252 + '...'
  end
end
