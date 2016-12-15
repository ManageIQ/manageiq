describe "LoadBalancer postprovision Method Validation" do
  let(:miq_request_task)      { FactoryGirl.create(:miq_request_task, :destination => service_load_balancer, :miq_request => request) }
  let(:request)               { FactoryGirl.create(:service_template_provision_request, :requester => user) }
  let(:service_load_balancer) { FactoryGirl.create(:service_load_balancer) }
  let(:user)                  { FactoryGirl.create(:user_with_group) }
  let(:ws)                    { MiqAeEngine.instantiate("/Cloud/LoadBalancer/Provisioning/StateMachines/Methods/PostProvision?MiqRequestTask::service_template_provision_task=#{miq_request_task.id}", user) }

  it "updates the owners of the resulting vm" do
    expect_any_instance_of(ServiceLoadBalancer).to receive(:post_provision_configure)
    ws
  end
end
