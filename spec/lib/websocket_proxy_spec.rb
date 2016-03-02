describe WebsocketProxy do
  let(:console) { FactoryGirl.create(:system_console) }
  let(:host) { '127.0.0.1:8080' }
  let(:uri) { '/ws/console/123456789' }
  let(:env) { {'HTTP_HOST' => host, 'REQUEST_URI' => uri, 'rack.hijack' => -> {}} }

  subject { described_class.new(env, console) }

  describe '#initialize' do
    it 'sets the URL' do
      expect(subject.url).to eq("ws://#{host}#{uri}")
    end
  end

  describe '#cleanup' do
    let(:ws) { double }
    let(:sock) { subject.instance_variable_get(:@sock) }
    it 'closes the sockets and removes the db record' do
      subject.instance_variable_set(:@ws, ws)
      expect(ws).to receive(:closed?).and_return(false)
      expect(ws).to receive(:close)

      subject.cleanup

      expect(sock.closed?).to be_truthy
      expect(console.destroyed?).to be_truthy
    end
  end

  describe '#descriptors' do
    let(:ws) { 0 }
    let(:sock) { 1 }

    it 'returns the socket descriptors' do
      subject.instance_variable_set(:@ws, ws)
      subject.instance_variable_set(:@sock, sock)

      expect(subject.descriptors).to eq [ws, sock]
    end
  end

  describe '#transmit' do
    let(:driver) { double }
    let(:ws) { double }
    let(:sock) { double }

    context 'websocket to socket' do
      let(:is_ws) { true }

      it 'reads from the websocket and parses the result' do
        subject.instance_variable_set(:@driver, driver)
        subject.instance_variable_set(:@ws, ws)
        subject.instance_variable_set(:@sock, sock)

        expect(ws).to receive(:recv_nonblock).and_return(123)
        expect(driver).to receive(:parse).with(123)

        subject.transmit([ws], is_ws)
      end
    end

    context 'socket to websocket' do
      let(:is_ws) { false }

      it 'reads from the socket and sends the result to the driver' do
        subject.instance_variable_set(:@driver, driver)
        subject.instance_variable_set(:@ws, ws)
        subject.instance_variable_set(:@sock, sock)

        expect(sock).to receive(:recv_nonblock).and_return(123)
        expect(driver).to receive(:binary).with(123)

        subject.transmit([sock], is_ws)
      end
    end
  end
end
