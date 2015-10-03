require "spec_helper"

describe WsProxy do
  before(:each) do
    stub_server_configuration(
      :server => {
        :websocket => {
          :cert => 'non-existent-foo-bar',
          :key  => 'REGION' # file existing under Rails root
        }
      }
    )
  end

  context '#try_run_proxy' do
    it "runs proxy by calling AwesomeSpawn with correct params" do
      port = 5900
      ws_proxy = WsProxy.new(:encrypt => true)

      expect(AwesomeSpawn).to receive(:run).with(
        ws_proxy.send(:ws_proxy),
        :params => {
          :daemon        => nil,
          :idle_timeout= => 120,
          :timeout=      => 120,
          :cert          => WsProxy::DEFAULT_CERT_FILE,
          :key           => 'REGION',
          nil            => [port, "0.0.0.0:5900"],
        }
      )

      ws_proxy.send(:try_run_proxy, port)
    end
  end
end
