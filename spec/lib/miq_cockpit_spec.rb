RSpec.describe MiqCockpit::WS do
  before do
    @server = FactoryBot.create(:miq_server, :hostname => "hostname")
    @miq_server = EvmSpecHelper.local_miq_server
    @miq_server.ipaddress = "10.0.0.1"
    @miq_server.has_active_userinterface = true

    allow(AwesomeSpawn).to receive(:run!)
  end

  describe '#url' do
    context "when using empty server" do
      it "it uses direct url" do
        expected = URI::HTTP.build(:host => "default-host",
                                   :port => 9090,
                                   :path => "/")
        expect(MiqCockpit::WS.url(nil, nil, "default-host")).to eq(expected)
      end
    end

    context "when using empty opts" do
      it "it uses defaults with apache" do
        expected = URI::HTTPS.build(:host => "hostname",
                                    :path => "/cws/=default-host")
        expect(MiqCockpit::WS.url(@server, nil, "default-host")).to eq(expected)
      end
    end

    context "when using external_host with path" do
      it "it uses it and preserves the path " do
        expected = URI::HTTPS.build(:host => "custom-host",
                                    :path => "/custom-path/=default-host")
        expect(MiqCockpit::WS.url(@server,
                                  {:external_url => "https://custom-host/custom-path"},
                                  "default-host")).to eq(expected)
      end
    end

    context "when using external_host without path" do
      it "it uses it with default path " do
        expected = URI::HTTP.build(:host => "custom-host",
                                   :path => "/cws/=default-host")
        expect(MiqCockpit::WS.url(@server,
                                  {:external_url => "http://custom-host"},
                                  "default-host")).to eq(expected)
      end
    end

    context "when using the same server as the ui without apache" do
      it "it uses defaults with apache" do
        expected = if MiqEnvironment::Command.is_appliance?
                     URI::HTTPS.build(:host => "10.0.0.1",
                                      :path => "/cws/=default-host")
                   else
                     URI::HTTP.build(:host => "10.0.0.1",
                                     :port => 9002,
                                     :path => "/cws/=default-host")
                   end

        expect(MiqCockpit::WS.url(@miq_server, nil, "default-host")).to eq(expected)
      end
    end

    context "when using the same server as the ui with apache" do
      it "it uses defaults with apache" do
        expect(MiqEnvironment::Command).to receive(:is_appliance?).once.and_return(true)
        expect(MiqEnvironment::Command).to receive(:supports_command?).once.and_return(true)
        expected = URI::HTTPS.build(:host => "10.0.0.1",
                                    :path => "/cws/=default-host")
        expect(MiqCockpit::WS.url(@miq_server, nil, "default-host")).to eq(expected)
      end
    end

    context "when using custom port with apache" do
      it "it uses https without port" do
        expected = URI::HTTPS.build(:host => "hostname",
                                    :path => "/cws/=default-host")
        expect(MiqCockpit::WS.url(@server,
                                  { :port => 8080 },
                                  "default-host")).to eq(expected)
      end
    end

    context "when using custom port with the same server without apache" do
      it "it uses the port" do
        with_port = if MiqEnvironment::Command.is_appliance?
                      URI::HTTPS.build(:host => "10.0.0.1",
                                       :path => "/cws/=default-host")
                    else
                      URI::HTTP.build(:host => "10.0.0.1",
                                      :port => 8080,
                                      :path => "/cws/=default-host")
                    end

        expect(MiqCockpit::WS.url(@miq_server,
                                  { :port => 8080 },
                                  "default-host")).to eq(with_port)
      end
    end
  end

  describe 'command' do
    context "when using empty opts" do
      it "it uses defaults" do
        ins = MiqCockpit::WS.new
        default_cmd = "#{MiqCockpit::WS::COCKPIT_WS_PATH} --port 9002 --address 127.0.0.1 --no-tls"
        expect(ins.command("127.0.0.1")).to eq(default_cmd)
      end
    end

    context "when using custom port" do
      it "it sets command arguments" do
        ins = MiqCockpit::WS.new(:port => "8000")
        cmd = "#{MiqCockpit::WS::COCKPIT_WS_PATH} --port 8000 --no-tls"
        expect(ins.command(nil)).to eq(cmd)
      end
    end
  end

  describe 'update_config' do
    context "when using empty opts" do
      it "it uses defaults" do
        ins = MiqCockpit::WS.new(nil)
        config = ins.update_config
        expect(config).to include("\n[SSH-Login]\ncommand = /usr/bin/cockpit-auth-miq\n")
        expect(config).to include("\n[Basic]\nAction = none\n")
        expect(config).to include("\n[Negotiate]\nAction = none\n")
        expect(config).to include("\nLoginTitle = ManageIQ Cockpit\n")
        expect(config).to include("\nUrlRoot = cws\n")
        expect(config).to include("\n[Bearer]\nAction = remote-login-ssh\n")
        expect(config).to include("\n[OAuth]\nUrl = /dashboard/cockpit_redirect\n")
      end
    end

    context "when using a active region" do
      it "it uses the full domain for the url" do
        MiqRegion.seed
        server = FactoryBot.create(:miq_server, :hostname => "hostname")
        expect(MiqRegion.my_region).to receive(:remote_ui_miq_server).once.and_return(server)

        ins = MiqCockpit::WS.new(nil)
        config = ins.update_config
        expect(config).to include("\n[OAuth]\nUrl = https://hostname/dashboard/cockpit_redirect\n")
      end
    end

    context "when options are set" do
      it "it uses them" do
        ins = MiqCockpit::WS.new(:title      => "Custom Title",
                                 :web_ui_url => "https://custom.url/")
        config = ins.update_config
        expect(config).to include("\nLoginTitle = Custom Title\n")
        expect(config).to include("\n[OAuth]\nUrl = https://custom.url/dashboard/cockpit_redirect\n")
      end
    end
  end
end

describe MiqCockpit::ApacheConfig do
  describe '#url_root ' do
    it "returns the correct URL path" do
      expect(MiqCockpit::ApacheConfig.url_root).to eq("/cws/")
    end
  end
end
