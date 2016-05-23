describe ContainerDeployment do
  before(:each) do
    @container_deployment = FactoryGirl.create(:container_deployment, :method_type => "existing_unmanaged", :version => "v3")
    @container_deployment.create_needed_tags

    hardware = FactoryGirl.create(:hardware)
    hardware.ipaddresses << "10.0.0.1"
    hardware.ipaddresses << "37.142.68.50"
    @container_deployment_node_with_vm_ip = FactoryGirl.create(:container_deployment_node, :vm => FactoryGirl.create(:vm_vmware, :hardware => hardware))
    hardware = FactoryGirl.create(:hardware)
    hardware.hostnames << "example.com"
    @container_deployment_node_with_vm_hostname = FactoryGirl.create(:container_deployment_node, :vm => FactoryGirl.create(:vm_vmware, :hardware => hardware))
    @container_deployment_node_without_vm = FactoryGirl.create(:container_deployment_node, :address => "10.0.0.2")

    @container_deployment_node_with_vm_ip.tag_add("node")
    @container_deployment_node_without_vm.tag_add("node")
    @container_deployment_node_with_vm_hostname.tag_add("deployment_master")

    @container_deployment.container_deployment_nodes << @container_deployment_node_with_vm_ip
    @container_deployment.container_deployment_nodes << @container_deployment_node_with_vm_hostname
    @container_deployment.container_deployment_nodes << @container_deployment_node_without_vm
    @container_deployment.create_deployment_authentication("mode" => "all")
    @container_deployment.create_deployment_authentication("ssh" => {"userid" => "root", "auth_key" => "-----BEGIN RSA PRIVATE KEY----- exmaple -----END RSA PRIVATE KEY-----", "public_key" => "public_key"}, "mode" => "ssh")
  end

  it "checks generate_ansible_yaml returns correct yaml" do
    expect(@container_deployment.generate_ansible_yaml).to eql(:version    => "v3",
                                                               :deployment => {:ansible_config   => ContainerDeployment::ANSIBLE_CONFIG_LOCATION,
                                                                               :ansible_ssh_user => "root",
                                                                               :hosts            => [{:connect_to => "37.142.68.50", :roles => "node"},
                                                                                                     {:connect_to => "example.com", :hostname => "example.com", :roles => "master"},
                                                                                                     {:connect_to => "10.0.0.2", :roles => "node"}],
                                                                               :roles            => {:master=>{:openshift_master_identity_providers=>[{"name" => "example_name", "login" => "true", "challenge" => "true", "kind" => "AllowAllPasswordIdentityProvider"}]}}})
  end

  it "creates needed tags" do
    expect(@container_deployment.create_needed_tags).to eq ["node", "master", "deployment_master"]
  end

  context "container deployment nodes" do
    it "checks extract_public_ip_or_hostname return correct address" do
      expect(@container_deployment.extract_public_ip_or_hostname(@container_deployment.container_deployment_nodes[0])).to eql("37.142.68.50")
      expect(@container_deployment.extract_public_ip_or_hostname(@container_deployment.container_deployment_nodes[1])).to eql("example.com")
      expect(@container_deployment.extract_public_ip_or_hostname(@container_deployment.container_deployment_nodes[2])).to eql("10.0.0.2")
    end

    it "create deployment nodes works properly" do
      @container_deployment.container_deployment_nodes.destroy_all
      @container_deployment.create_deployment_nodes([[{"vmName" => "10.0.0.2"}, {"vmName" => "37.142.68.50"}], [], [{"vmName" => "example.com"}]], nil, ["node", "master", "deployment_master"])
      expect(@container_deployment.container_nodes_by_role("node").count).to eql(2)
      expect(@container_deployment.container_nodes_by_role("master").count).to eql(0)
      expect(@container_deployment.container_nodes_by_role("deployment_master").count).to eql(1)
      @container_deployment.container_deployment_nodes.destroy_all
    end
  end
end
