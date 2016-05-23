describe ApiController do
  describe "Container Deployment create" do
    let(:container_deployment_create_request) do
      {
        "providerName"       => "dfssasaasdsasada",
        "providerType"       => "openshiftEnterprise",
        "provisionOn"        => "exisiting_non_managed",
        "authentication"     => {"mode" => "all"},
        "masters"            => [{"vmName" => "10.0.0.1"}],
        "nodes"              => [{"vmName" => "10.0.0.1"}, {"vmName" => "10.0.0.2"}],
        "deploymentKey"      => "-----BEGIN RSA PRIVATE KEY----- private_key -----END RSA PRIVATE KEY-----",
        "deploymentUsername" => "root",
        "deploymentPassword" => "fds",
        "rhnUsername"        => "exmaple@redhat.com",
        "rhnPassword"        => "pass",
        "rhnSKU"             => "ES0113909"
      }
    end

    it "supports create request with post" do
      api_basic_authorize collection_action_identifier(:container_deployments, :create)
      allow(AutomationRequest).to receive(:create_from_ws).and_return(true)
      run_post(container_deployments_url, gen_request(:create, container_deployment_create_request))
      expect_request_success
      container_deployment_id = response_hash["results"].first["id"]
      expect(ContainerDeployment.exists?(container_deployment_id)).to be_truthy
      expect(ContainerDeployment.find(container_deployment_id).container_deployment_nodes.count).to eq 2
      expect(ContainerDeployment.find(container_deployment_id).ssh_auth.nil?).to be_falsey
      expect(ContainerDeployment.find(container_deployment_id).rhsm_auth.nil?).to be_falsey
      expect(ContainerDeployment.find(container_deployment_id).identity_provider_auth.empty?).to be_falsey
    end
  end

  describe "Container Deployment collect data" do
    let(:container_deployment_collect_data_request) do
      {
        "no_resource" => true
      }
    end
    it "supports collect-data with post" do
      allow_any_instance_of(ContainerDeploymentService).to receive(:all_data).and_return(true)
      api_basic_authorize collection_action_identifier(:container_deployments, :collect_data)
      run_post(container_deployments_url, gen_request(:collect_data, container_deployment_collect_data_request))
      expect_request_success
    end

  end
end
