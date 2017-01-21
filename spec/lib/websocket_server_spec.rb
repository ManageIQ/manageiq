describe WebsocketServer do
  before do
    %i(fatal error warn info debug level).each { |method| allow(logger).to receive(method) }
    @server = described_class.new(:logger => logger)
    Thread.list.reject { |t| t == Thread.current }.each(&:kill)
  end

  let(:logger) { double }

  describe '#call' do
    let(:env) { Hash.new }
    subject { @server.call(env) }

    context 'invalid request' do
      before { allow(@server).to receive(:parse_request).and_return(:error) }

      it 'returns with a not found error' do
        is_expected.to eq(@server.send(:not_found))
      end
    end

    context 'ActionCable request' do
      before { allow(@server).to receive(:parse_request).and_return(:cable) }

      it 'passes the request to ActionCable' do
        expect(ActionCable.server).to receive(:call).with(env)
        is_expected.to be_nil
      end
    end

    context 'request for a remote console' do
      before { allow(@server).to receive(:parse_request).and_return('123456') }

      it 'initializes the proxy' do
        expect(@server).to receive(:init_proxy)
        is_expected.to be_nil
      end
    end
  end

  describe '#init_proxy' do
    let(:proxy) { @server.instance_variable_get(:@proxy) }
    let(:ws) { dup }
    let(:sock) { dup }

    let(:env) { { 'rack.hijack' => -> { ws } } }
    let(:url_secret) { '123456' }
    let(:ssl) { false }
    let(:driver) do
      drv = WebSocket::Handshake::Server.new
      drv.from_rack(env)
      drv
    end

    before do
      FactoryGirl.create(:system_console, :url_secret => '123456', :ssl => ssl)
      allow(ws).to receive(:close)
      allow(sock).to receive(:close)
      allow(driver).to receive(:to_s).and_return("abcd")
      allow(ws).to receive(:write_nonblock).with("abcd")
      allow(WebsocketDecorator).to receive(:decorate).with(ws, driver.version).and_return(ws)
      allow(TCPSocket).to receive(:open).and_return(sock)
    end

    subject { @server.send(:init_proxy, env, url_secret, driver) }

    context 'console does not exist' do
      let(:url_secret) { '1234567' }

      it 'returns with not_found' do
        is_expected.to eq(@server.send(:not_found))
      end
    end

    context 'rack.hijack is unsuccessful' do
      let(:env) { { 'rack.hijack' => -> { raise } } }

      it 'returns with not_found' do
        is_expected.to eq(@server.send(:not_found))
      end
    end

    context 'cannot write to the websocket' do
      before { allow(ws).to receive(:write_nonblock).and_raise }

      it 'returns with not found' do
        is_expected.to eq(@server.send(:not_found))
      end
    end

    context 'cannot open remote endpoint' do
      before { allow(TCPSocket).to receive(:open).and_raise }

      it 'returns with not found' do
        is_expected.to eq(@server.send(:not_found))
      end
    end

    context 'SSL is enabled' do
      let(:ssl) { true }

      it 'sets up SSL' do
        expect(@server).to receive(:init_ssl).and_return(sock)
        expect(proxy).to receive(:push).with(sock, ws)
        is_expected.to eq([-1, {}, []])
      end
    end

    it 'sets up proxying' do
      expect(proxy).to receive(:push).with(sock, ws)
      is_expected.to eq([-1, {}, []])
    end
  end

  describe '#not_found' do
    subject { @server.send(:not_found) }

    it '404 http response' do
      expect(subject[0]).to eq(404)
    end

    it 'textual content type' do
      expect(subject[1]).to eq('Content-Type' => 'text/plain')
    end
  end

  describe '#parse_request' do
    subject { @server.send(:parse_request, env, driver) }

    before do
      allow(@server).to receive(:same_origin_as_host?).and_return(same)
    end

    context 'invalid websocket request' do
      let(:env) { Hash.new }
      let(:same) { true }
      let(:driver) { OpenStruct.new(:valid? => false, :finished? => true) }

      it 'returns with :error' do
        is_expected.to eq(:error)
      end
    end

    context 'unfinished websocket handshake' do
      let(:env) { Hash.new }
      let(:same) { true }
      let(:driver) { OpenStruct.new(:valid? => true, :finished? => false) }

      it 'returns with :error' do
        is_expected.to eq(:error)
      end
    end

    context 'not the same origin as host' do
      let(:env) { Hash.new }
      let(:same) { false }
      let(:driver) { OpenStruct.new(:valid? => true, :finished? => true) }

      it 'returns with :error' do
        is_expected.to eq(:error)
      end
    end

    context 'ActionCable request' do
      let(:env) { {'REQUEST_URI' => '/ws/notifications'} }
      let(:same) { true }
      let(:driver) { OpenStruct.new(:valid? => true, :finished? => true) }

      it 'returns with :cable' do
        is_expected.to eq(:cable)
      end
    end

    context 'invalid url' do
      let(:env) { {'REQUEST_URI' => '/ws/blablabla'} }
      let(:same) { true }
      let(:driver) { OpenStruct.new(:valid? => true, :finished? => true) }

      it 'returns with :error' do
        is_expected.to eq(:error)
      end
    end

    context 'console request' do
      let(:env) { {'REQUEST_URI' => '/ws/console/123456'} }
      let(:same) { true }
      let(:driver) { OpenStruct.new(:valid? => true, :finished? => true) }

      it 'returns with the console id' do
        is_expected.to eq('123456')
      end
    end
  end

  describe '#same_origin_as_host?' do
    subject { @server.send(:same_origin_as_host?, env) }

    context 'same origin as host' do
      let(:env) { {'HTTP_ORIGIN' => 'http://manageiq.org', 'HTTP_HOST' => 'manageiq.org'} }

      it 'returns with true' do
        is_expected.to be_truthy
      end
    end

    context 'origin different from the host' do
      let(:env) { {'HTTP_ORIGIN' => 'http://manageiq.org', 'HTTP_HOST' => 'github.com'} }

      it 'returns with false' do
        is_expected.to be_falsey
      end
    end
  end
end
