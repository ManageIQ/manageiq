describe MiqCockpitWsWorker::Authenticator do
  describe '#authenticate_for_host' do
    before(:each) do
      @auth = MiqCockpitWsWorker::Authenticator
      @user = FactoryGirl.create(:user, :userid => 1)
      @token = Api::Environment.user_token_service.generate_token(1, "api")
    end

    context "when using bad token" do
      it "fails to authenticate" do
        expect(@auth.authenticate_for_host("bad", "host")).to eq({})
      end
    end

    context "when host is" do
      before do
        @hardware = FactoryGirl.create(:hardware)
        @vm = FactoryGirl.create(:vm_openstack, :hardware => @hardware)
        @hardware.networks << FactoryGirl.create(:network, :ipaddress => "10.0.0.1", :hostname => "vm-host1")
        @hardware.networks << FactoryGirl.create(:network, :ipaddress => "10.0.0.2", :hostname => "vm-host2")
        @container_deployment = FactoryGirl.create(:container_deployment,
                                                   :method_type => "non_managed",
                                                   :version     => "v2",
                                                   :kind        => "openshift-enterprise")

        @vmkey = "-----BEGIN RSA PRIVATE KEY----- vm-key -----END RSA PRIVATE KEY-----"
        @deploykey = "-----BEGIN RSA PRIVATE KEY----- deploy-key -----END RSA PRIVATE KEY-----"
        @found = {
          :valid  => true,
          :known  => true,
          :key    => nil,
          :userid => nil,
        }

        @not_found = {
          :valid  => true,
          :known  => false,
          :key    => nil,
          :userid => nil,
        }
      end

      it "not known returns that host is unknown" do
        expect(@auth.authenticate_for_host(@token, "10.0.0.3")).to eq(@not_found)
        expect(@auth.authenticate_for_host(@token, "vm-host3")).to eq(@not_found)
      end

      it "a known vm and has no auth returns that host is known without auth" do
        expect(@auth.authenticate_for_host(@token, "10.0.0.1")).to eq(@found)
        expect(@auth.authenticate_for_host(@token, "10.0.0.2")).to eq(@found)
        expect(@auth.authenticate_for_host(@token, "vm-host1")).to eq(@found)
        expect(@auth.authenticate_for_host(@token, "vm-host2")).to eq(@found)
      end

      it "a known vm with a key pair returns that host with auth" do
        pair = FactoryGirl.create(:auth_key_pair_cloud,
                                  :userid     => "vm",
                                  :auth_key   => @vmkey,
                                  :public_key => "public_key",
                                  :type       => "AuthPrivateKey")
        pair.vms << @vm
      end

      it "a container node name returns known vm with no auth" do
        FactoryGirl.create(:container_node, :name => "kube-node.name")
        expect(@auth.authenticate_for_host(@token, "kube-node.name")).to eq(@found)
      end

      it "a container deployment node address uses container deploy auth" do
        FactoryGirl.create(:container_deployment_node,
                           :address              => "cd-node.address",
                           :container_deployment => @container_deployment)

        expect(@auth.authenticate_for_host(@token, "cd-node.address")).to eq(@found)

        @container_deployment.create_deployment_authentication("userid"     => "root",
                                                               "auth_key"   => @deploykey,
                                                               "public_key" => "public_key",
                                                               "type"       => "AuthPrivateKey")

        expect(@auth.authenticate_for_host(@token, "cd-node.address")).to eq(
          :valid  => true,
          :known  => true,
          :key    => @deploykey,
          :userid => "root",
        )
      end

      it "a container deployment node vm uses container deployment auth" do
        @container_deployment.create_deployment_authentication("userid"     => "root",
                                                               "auth_key"   => @deploykey,
                                                               "public_key" => "public_key",
                                                               "type"       => "AuthPrivateKey")

        FactoryGirl.create(:container_deployment_node,
                           :vm                   => @vm,
                           :container_deployment => @container_deployment)

        expect(@auth.authenticate_for_host(@token, "vm-host1")).to eq(
          :valid  => true,
          :known  => true,
          :key    => @deploykey,
          :userid => "root",
        )
      end
    end
  end
end
