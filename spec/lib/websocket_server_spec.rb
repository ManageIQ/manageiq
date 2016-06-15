describe WebsocketServer do
  before(:each) do
    allow(logger).to receive(:info)
    @server = described_class.new(:logger => logger)
    Thread.list.reject { |t| t == Thread.current }.each(&:kill)
  end

  let(:sockets) { @server.instance_variable_get(:@sockets) }
  let(:pairing) { @server.instance_variable_get(:@pairing) }
  let(:logger) { double }

  let(:pipes) { IO.pipe }
  let(:left) { pipes.first }
  let(:right) { pipes.last }
  let(:proxy) { double }

  describe '#call' do
    subject { @server.call(env) }

    context 'non-websocket' do
      let(:env) { Hash.new }

      it 'returns with a not found error' do
        is_expected.to eq(@server.send(:not_found))
      end
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

  describe '#cleanup' do
    subject { @server.send(:cleanup, error) }

    before(:each) do
      pairing.merge!(
        left  => WebsocketServer::Pairing.new(true, proxy),
        right => WebsocketServer::Pairing.new(false, proxy)
      )
      sockets.push(left, right)
      allow(proxy).to receive(:vm_id).and_return('unknown')
    end

    let(:error) { right }

    it 'removes the failed socket' do
      expect(proxy).to receive(:cleanup)
      subject
      expect(sockets).to_not include(right)
      expect(pairing.keys).to_not include(right)
    end
  end
end
