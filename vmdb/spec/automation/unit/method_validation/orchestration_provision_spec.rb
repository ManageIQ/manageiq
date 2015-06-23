require 'spec_helper'

describe "Orchestration provision Method Validation" do
  let(:miq_request_task)      { FactoryGirl.create(:miq_request_task, :destination => service_orchestration, :miq_request => request) }
  let(:request)               { FactoryGirl.create(:service_template_provision_request, :userid => user.userid) }
  let(:service_orchestration) { FactoryGirl.create(:service_orchestration) }
  let(:user)                  { FactoryGirl.create(:user) }
  let(:ws)                    { MiqAeEngine.instantiate("/Cloud/Orchestration/Provisioning/StateMachines/Methods/Provision?MiqRequestTask::service_template_provision_task=#{miq_request_task.id}") }

  it "provisions a stack through the service" do
    ServiceOrchestration.any_instance.should_receive(:deploy_orchestration_stack)
    ws
  end

  it "catches the error at stack provisioning" do
    ServiceOrchestration.any_instance.stub(:deploy_orchestration_stack) { raise "test failure" }
    ws.root['ae_result'].should == "error"
    ws.root['ae_reason'].should == "test failure"
  end
end
