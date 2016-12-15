describe "LoadBalancer provision Method Validation" do
  let(:miq_request_task)      { FactoryGirl.create(:miq_request_task, :destination => service_load_balancer, :miq_request => request) }
  let(:request)               { FactoryGirl.create(:service_template_provision_request, :requester => user) }
  let(:service_load_balancer) { FactoryGirl.create(:service_load_balancer) }
  let(:user)                  { FactoryGirl.create(:user_with_group) }
  let(:ws)                    { MiqAeEngine.instantiate("/Cloud/LoadBalancer/Provisioning/StateMachines/Methods/Provision?MiqRequestTask::service_template_provision_task=#{miq_request_task.id}", user) }

  it "provisions a load_balancer through the service" do
    expect_any_instance_of(ServiceLoadBalancer).to receive(:deploy_load_balancer)
    ws
  end

  it "catches the error at load_balancer provisioning" do
    allow_any_instance_of(ServiceLoadBalancer).to receive(:deploy_load_balancer) { raise "test failure" }
    expect(ws.root['ae_result']).to eq("error")
    expect(ws.root['ae_reason']).to eq("test failure")
    expect(request.reload.message).to eq("test failure")
  end

  it "truncates the error message exceeding 255 character limits" do
    long_error = 't' * 300
    allow_any_instance_of(ServiceLoadBalancer).to receive(:deploy_load_balancer) { raise long_error }
    expect(ws.root['ae_result']).to eq("error")
    expect(ws.root['ae_reason']).to eq(long_error)
    expect(request.reload.message).to eq('t' * 252 + '...')
  end
end
