describe "Orchestration postprovision Method Validation" do
  let(:miq_request_task)      { FactoryGirl.create(:miq_request_task, :destination => service_orchestration, :miq_request => request) }
  let(:request)               { FactoryGirl.create(:service_template_provision_request, :requester => user) }
  let(:service_orchestration) { FactoryGirl.create(:service_orchestration) }
  let(:user)                  { FactoryGirl.create(:user_with_group) }
  let(:deploy_result)         { 'deploy_error' }
  let(:ws_url)                { "/Cloud/Orchestration/Provisioning/StateMachines/Methods/PostProvision?MiqRequestTask::service_template_provision_task=#{miq_request_task.id}" }
  let(:ws)                    { MiqAeEngine.instantiate("#{ws_url}&ae_state_data=#{URI.escape(YAML.dump('deploy_result' => deploy_result))}", user) }

  it "notifies the service to do post-provisioning configuration" do
    expect_any_instance_of(ServiceOrchestration).to receive(:post_provision_configure)
    ws
  end

  it "sets ae_result from provisioning state" do
    expect(ws.root['ae_result']).to eq(deploy_result)
  end
end
