RSpec.describe MiqCockpitWsWorker::Authenticator do
  describe '#authenticate_for_host' do
    before do
      @auth = MiqCockpitWsWorker::Authenticator
      @user = FactoryBot.create(:user, :userid => "admin")
      @token = Api::UserTokenService.new.generate_token(@user.userid, 'api')
    end

    context "when using bad token" do
      it "fails to authenticate" do
        expect(@auth.authenticate_for_host("bad", "host")).to eq({})
      end
    end

    context "when host is" do
      before do
        @hardware = FactoryBot.create(:hardware)
        @vm = FactoryBot.create(:vm_openstack, :hardware => @hardware)
        @hardware.networks << FactoryBot.create(:network, :ipaddress => "10.0.0.1", :hostname => "vm-host1")
        @hardware.networks << FactoryBot.create(:network, :ipaddress => "10.0.0.2", :hostname => "vm-host2")

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
        pair = FactoryBot.create(:auth_key_pair_cloud,
                                  :userid     => "vm",
                                  :auth_key   => @vmkey,
                                  :public_key => "public_key",
                                  :type       => "AuthPrivateKey")
        pair.vms << @vm
      end
    end
  end
end
