require 'spec_helper'

describe "Orchestration provision Method Validation" do
  let(:ws) do
    MiqAeEngine.instantiate("/Cloud/Orchestration/Provisioning/StateMachines/Methods/Provision?" \
      "MiqRequestTask::service_template_provision_task=#{miq_request_task.id}")
  end

  let(:miq_request_task) do
    FactoryGirl.create(:miq_request_task,
                       :destination => service_orchestration,
                       :miq_request => FactoryGirl.create(:automation_request),
                       :state       => 'active',
                       :status      => 'Ok')
  end

  let(:service_orchestration) do
    FactoryGirl.create(:service_orchestration)
  end

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
