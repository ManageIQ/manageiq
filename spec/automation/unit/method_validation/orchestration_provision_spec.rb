describe "Orchestration provision Method Validation" do
  let(:miq_request_task)      { FactoryGirl.create(:miq_request_task, :destination => service_orchestration, :miq_request => request) }
  let(:request)               { FactoryGirl.create(:service_template_provision_request, :requester => user) }
  let(:service_orchestration) { FactoryGirl.create(:service_orchestration) }
  let(:user)                  { FactoryGirl.create(:user_with_group) }
  let(:ws)                    { MiqAeEngine.instantiate("/Cloud/Orchestration/Provisioning/StateMachines/Methods/Provision?MiqRequestTask::service_template_provision_task=#{miq_request_task.id}", user) }

  it "provisions a stack through the service" do
    expect_any_instance_of(ServiceOrchestration).to receive(:deploy_orchestration_stack)
    ws
  end

  it "catches the error at stack provisioning" do
    allow_any_instance_of(ServiceOrchestration).to receive(:deploy_orchestration_stack) { raise "test failure" }
    expect(ws.root['ae_result']).to eq("error")
    expect(ws.root['ae_reason']).to eq("test failure")
    expect(request.reload.message).to eq("Service_Template_Provisioning - Request Created")
  end

  it "truncates the error message exceeding 255 character limits" do
    long_error = 't' * 300
    allow_any_instance_of(ServiceOrchestration).to receive(:deploy_orchestration_stack) { raise long_error }
    expect(ws.root['ae_result']).to eq("error")
    expect(ws.root['ae_reason']).to eq(long_error)
    expect(request.reload.message).to eq("Service_Template_Provisioning - Request Created")
  end
end
