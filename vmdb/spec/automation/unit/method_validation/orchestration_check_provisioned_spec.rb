require 'spec_helper'

describe "Orchestration check_provisioned Method Validation" do
  let(:stack_ems_ref) { "12345" }
  let(:deploy_result) { "deploy result" }
  let(:failure_msg) { "failure message" }

  let(:ws_url) do
    "/Cloud/Orchestration/Provisioning/StateMachines/Methods/CheckProvisioned?" \
    "MiqRequestTask::service_template_provision_task=#{miq_request_task.id}"
  end

  let(:ws) do
    MiqAeEngine.instantiate(ws_url)
  end

  let(:ws_with_refresh_started) do
    @ae_state   = {'provider_last_refresh' => Time.now, 'deploy_result' => deploy_result}
    MiqAeEngine.instantiate("#{ws_url}&ae_state_data=#{URI.escape(YAML.dump(@ae_state))}")
  end

  let(:miq_request_task) do
    FactoryGirl.create(:miq_request_task,
                       :destination => service_orchestration,
                       :miq_request => FactoryGirl.create(:miq_request),
                       :state       => 'active',
                       :status      => 'Ok')
  end

  let(:service_orchestration) do
    FactoryGirl.create(:service_orchestration,
                       :orchestration_manager => FactoryGirl.create(:ems_amazon, :last_refresh_date => Time.now - 100))
  end

  it "waits for the deployment to complete" do
    ServiceOrchestration.any_instance.stub(:orchestration_stack_status) { ['CREATING', nil] }
    ws.root['ae_result'].should == 'retry'
  end

  it "catches the error during stack deployment" do
    ServiceOrchestration.any_instance.stub(:orchestration_stack_status) { ['CREATE_FAILED', failure_msg] }
    ws.root['ae_result'].should == 'error'
    ws.root['ae_reason'].should == failure_msg
  end

  it "considers rollback as provision error" do
    ServiceOrchestration.any_instance.stub(:orchestration_stack_status) { ['ROLLBACK_COMPLETE', nil] }
    ws.root['ae_result'].should == 'error'
    ws.root['ae_reason'].should == 'Stack was rolled back'
  end

  it "refreshes the provider and waits for it to complete" do
    ServiceOrchestration.any_instance.stub(:orchestration_stack_status) { ['CREATE_COMPLETE', nil] }
    ServiceOrchestration.any_instance.stub(:stack_ems_ref) { stack_ems_ref }
    EmsAmazon.any_instance.should_receive(:refresh_ems)
    ws.root['ae_result'].should == 'retry'
  end

  it "waits the refresh to complete" do
    ws_with_refresh_started.root['ae_result'].should == "retry"
  end

  it "completes check_provisioned step when refresh is done" do
    ServiceOrchestration.any_instance.stub(:stack_ems_ref) { stack_ems_ref }
    FactoryGirl.create(:orchestration_stack, :ems_ref => stack_ems_ref)
    ws_with_refresh_started.root['ae_result'].should == deploy_result
  end
end
