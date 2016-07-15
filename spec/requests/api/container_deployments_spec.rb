describe ApiController do
  it "supports collect-data with GET" do
    allow_any_instance_of(ContainerDeploymentService).to receive(:cloud_init_template_id).and_return(1)
    api_basic_authorize collection_action_identifier(:container_deployments, :read, :get)
    run_get container_deployments_url + "/container_deployment_data"
    expect(response).to have_http_status(:ok)
    expect_hash_to_have_only_keys(response.parsed_body["data"], %w(providers provision))
  end

  it "creates container deployment with POST" do
    allow_any_instance_of(ContainerDeployment).to receive(:create_deployment).and_return(true)
    api_basic_authorize collection_action_identifier(:container_deployments, :create)
    run_post(container_deployments_url, gen_request(:create, :example_data => true))
    expect(response).to have_http_status(:ok)
  end
end
