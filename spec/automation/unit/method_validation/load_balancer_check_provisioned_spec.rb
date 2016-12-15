describe "LoadBalancer check_provisioned Method Validation" do
  let(:deploy_result)           { "deploy result" }
  let(:ems_amazon)              { FactoryGirl.create(:ems_amazon, :last_refresh_date => Time.now - 100) }
  let(:failure_msg)             { "failure message" }
  let(:long_failure_msg)        { "t" * 300 }
  let(:load_balancer_ems_ref)   { "12345" }
  let(:user)                    { FactoryGirl.create(:user_with_group) }
  let(:ws)                      { MiqAeEngine.instantiate(ws_url, user) }
  let(:ws_url)                  { "/Cloud/LoadBalancer/Provisioning/StateMachines/Methods/CheckProvisioned?MiqRequestTask::service_template_provision_task=#{miq_request_task.id}" }
  let(:ws_with_refresh_started) { MiqAeEngine.instantiate("#{ws_url}&ae_state_data=#{URI.escape(YAML.dump('provider_last_refresh' => Time.now.to_i, 'deploy_result' => deploy_result))}", user) }
  let(:miq_request_task) do
    FactoryGirl.create(:miq_request_task,
                       :destination => service_load_balancer,
                       :miq_request => request)
  end
  let(:request) do
    FactoryGirl.create(:service_template_provision_request,
                       :requester => user)
  end
  let(:service_load_balancer) do
    FactoryGirl.create(:service_load_balancer,
                       :load_balancer_manager => ems_amazon)
  end

  it "waits for the deployment to complete" do
    allow_any_instance_of(ServiceLoadBalancer).to receive(:load_balancer_status) { ['CREATING', nil] }
    expect(ws.root['ae_result']).to eq('retry')
  end

  it "catches the error during load Balancer deployment" do
    allow_any_instance_of(ServiceLoadBalancer)
      .to receive(:load_balancer_status).and_return(['CREATE_FAILED', failure_msg])
    expect(ws.root['ae_result']).to eq('error')
    expect(ws.root['ae_reason']).to eq(failure_msg)
    expect(request.reload.message).to eq(failure_msg)
  end

  it "truncates the error message that exceeds 255 characters" do
    allow_any_instance_of(ServiceLoadBalancer)
      .to receive(:load_balancer_status).and_return(['CREATE_FAILED', long_failure_msg])
    expect(ws.root['ae_result']).to eq('error')
    expect(ws.root['ae_reason']).to eq(long_failure_msg)
    expect(request.reload.message).to eq('t' * 252 + '...')
  end

  it "considers rollback as provision error" do
    allow_any_instance_of(ServiceLoadBalancer)
      .to receive(:load_balancer_status) { ['ROLLBACK_COMPLETE', 'Load Balancer was rolled back'] }
    expect(ws.root['ae_result']).to eq('error')
    expect(ws.root['ae_reason']).to eq('Load Balancer was rolled back')
  end

  it "refreshes the provider and waits for it to complete" do
    allow_any_instance_of(ServiceLoadBalancer)
      .to receive(:load_balancer_status) { ['CREATE_COMPLETE', nil] }
    allow_any_instance_of(ServiceLoadBalancer)
      .to receive(:load_balancer) { FactoryGirl.create(:load_balancer_amazon) }
    expect_any_instance_of(ManageIQ::Providers::Amazon::CloudManager).to receive(:refresh_ems)
    expect(ws.root['ae_result']).to eq('retry')
  end

  it "waits the refresh to complete" do
    expect(ws_with_refresh_started.root['ae_result']).to eq("retry")
  end

  it "completes check_provisioned step when refresh is done" do
    ems_amazon.update_attributes(:last_refresh_date => Time.now + 100)
    expect(ws_with_refresh_started.root['ae_result']).to eq(deploy_result)
  end
end
