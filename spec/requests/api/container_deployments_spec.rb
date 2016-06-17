describe ApiController do
  describe "Container Deployment create" do
    let(:container_deployment_create_request) do
      {
        "provider_name": "dfssasaasdsasada",
        "provider_type": "openshift-enterprise",
        "method_type": "exisiting_non_managed",
        "nodes": [{
                    "name": "10.0.0.1",
                    "id": nil,
                    "roles": {
                      "node": true,
                      "master": true,
                      "dns": false,
                      "etcd": false,
                      "infrastructure": false,
                      "load_balancer": false,
                      "storage": false
                    }
                  }, {
                    "name": "10.0.0.2",
                    "id": nil,
                    "roles": {
                      "node": true,
                      "master": false,
                      "dns": false,
                      "etcd": false,
                      "infrastructure": false,
                      "load_balancer": false,
                      "storage": false
                    }
                  }],
        "underline_provider_id": 1,
        "identity_authentication": {
          "mode": "AuthenticationAllowAll"
        },
        "ssh_authentication": {
          "mode": "AuthPrivateKey",
          "auth_key": "-----BEGIN RSA PRIVATE KEY----- privatekey -----END RSA PRIVATE KEY-----",
          "user_id": "root"
        },
        "rhsm_authentication": {
          "mode": "AuthenticationRhsm",
          "userid": "userid",
          "password": "pass",
          "rhsm_sku": "sku"
        }
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
