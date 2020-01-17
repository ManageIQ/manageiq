RSpec.describe RemoteConsole::RackServer do
  before do
    allow(logger).to receive(:info)
    @server = described_class.new(:logger => logger)
    Thread.list.reject { |t| t == Thread.current }.each(&:kill)
  end

  let(:adapters) { @server.instance_variable_get(:@adapters) }
  let(:proxy) { @server.instance_variable_get(:@proxy) }
  let(:logger) { double }

  let(:pipes) { IO.pipe }
  let(:left) { pipes.first }
  let(:right) { pipes.last }

  let(:hijack) { double }
  let(:env) { {'REQUEST_URI' => "/ws/#{url}", 'rack.hijack' => hijack} }

  describe '#call' do
    context 'remote console' do
      let(:url) { 'console/12345' }

      it 'calls init_proxy' do
        allow(WebSocket::Driver).to receive(:websocket?).with(env).and_return(true)
        allow(subject).to receive(:same_origin_as_host?).with(env).and_return(true)

        expect(subject).to receive(:init_proxy).with(env, '12345')

        subject.call(env)
      end
    end

    context 'any other URL' do
      let(:url) { 'haha' }

      it 'returns with 404' do
        expect(subject.call(env)).to eq(described_class::RACK_404)
      end
    end
  end

  describe '#init_proxy' do
    let(:proxy) { subject.instance_variable_get(:@proxy) }
    let(:protocol) { 'vnc' }
    let(:url) { 'console/12345' }
    let!(:console) { FactoryBot.create(:system_console, :url_secret => '12345', :protocol => protocol) }
    let(:init) { subject.send(:init_proxy, env, '12345') }

    before do
      allow(hijack).to receive(:call).and_return(left)
      allow(TCPSocket).to receive(:open).and_return(right)
    end

    context 'nonexistent console' do
      let(:console) { nil }

      it 'raises an AR exception' do
        expect { init }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'rack hijack fail' do
      it 'returns with 404' do
        allow(hijack).to receive(:call).and_raise(StandardError)
        expect(init).to eq(described_class::RACK_404)
      end
    end

    it 'pushes two sockets to the proxy' do
      allow(RemoteConsole::ServerAdapter).to receive(:new) # prevent writing to the dummy socket
      expect(proxy).to receive(:push).with(left, right)

      expect(init).to eq(described_class::RACK_YAY)
    end
  end

  describe '#cleanup' do
    before do
      adapters.merge!(left => nil, right => nil)
    end

    it 'removes the failed socket' do
      expect(left).to receive(:close)
      expect(right).to receive(:close)
      expect(proxy).to receive(:pop).with(left, right)

      @server.send(:cleanup, :debug, nil, left, right)

      expect(adapters.keys).not_to include(left)
      expect(adapters.keys).not_to include(right)
    end
  end
end
