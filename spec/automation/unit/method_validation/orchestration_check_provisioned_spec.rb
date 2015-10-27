require 'spec_helper'

describe "Orchestration check_provisioned Method Validation" do
  let(:deploy_result)           { "deploy result" }
  let(:ems_amazon)              { FactoryGirl.create(:ems_amazon, :last_refresh_date => Time.now - 100) }
  let(:failure_msg)             { "failure message" }
  let(:miq_request_task)        { FactoryGirl.create(:miq_request_task, :destination => service_orchestration, :miq_request => request) }
  let(:request)                 { FactoryGirl.create(:service_template_provision_request, :requester => user) }
  let(:service_orchestration)   { FactoryGirl.create(:service_orchestration, :orchestration_manager => ems_amazon) }
  let(:stack_ems_ref)           { "12345" }
  let(:user)                    { FactoryGirl.create(:user_with_group) }
  let(:ws)                      { MiqAeEngine.instantiate(ws_url, user) }
  let(:ws_url)                  { "/Cloud/Orchestration/Provisioning/StateMachines/Methods/CheckProvisioned?MiqRequestTask::service_template_provision_task=#{miq_request_task.id}" }
  let(:ws_with_refresh_started) { MiqAeEngine.instantiate("#{ws_url}&ae_state_data=#{URI.escape(YAML.dump('provider_last_refresh' => Time.now.to_i, 'deploy_result' => deploy_result))}", user) }

  it "waits for the deployment to complete" do
    ServiceOrchestration.any_instance.stub(:orchestration_stack_status) { ['CREATING', nil] }
    ws.root['ae_result'].should == 'retry'
  end

  it "catches the error during stack deployment" do
    ServiceOrchestration.any_instance.stub(:orchestration_stack_status) { ['CREATE_FAILED', failure_msg] }
    ws.root['ae_result'].should == 'error'
    ws.root['ae_reason'].should == failure_msg
    request.reload.message.should == failure_msg
  end

  it "truncates the error message that exceeds 255 characters" do
    long_error = 't' * 300
    ServiceOrchestration.any_instance.stub(:orchestration_stack_status) { ['CREATE_FAILED', long_error] }
    ws.root['ae_result'].should == 'error'
    ws.root['ae_reason'].should == long_error
    request.reload.message.should == 't' * 252 + '...'
  end

  it "considers rollback as provision error" do
    ServiceOrchestration.any_instance.stub(:orchestration_stack_status) { ['ROLLBACK_COMPLETE', 'Stack was rolled back'] }
    ws.root['ae_result'].should == 'error'
    ws.root['ae_reason'].should == 'Stack was rolled back'
  end

  it "refreshes the provider and waits for it to complete" do
    ServiceOrchestration.any_instance.stub(:orchestration_stack_status) { ['CREATE_COMPLETE', nil] }
    ServiceOrchestration.any_instance.stub(:orchestration_stack) { FactoryGirl.create(:orchestration_stack_amazon) }
    ManageIQ::Providers::Amazon::CloudManager.any_instance.should_receive(:refresh_ems)
    ws.root['ae_result'].should == 'retry'
  end

  it "waits the refresh to complete" do
    ws_with_refresh_started.root['ae_result'].should == "retry"
  end

  it "completes check_provisioned step when refresh is done" do
    ems_amazon.update_attributes(:last_refresh_date => Time.now + 100)
    ws_with_refresh_started.root['ae_result'].should == deploy_result
  end
end
