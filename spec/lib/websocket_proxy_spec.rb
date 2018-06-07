describe WebsocketProxy do
  let(:console) { FactoryGirl.create(:system_console) }
  let(:host) { '127.0.0.1:8080' }
  let(:uri) { '/ws/console/123456789' }
  let(:logger) { double }
  let(:env) { {'HTTP_HOST' => host, 'REQUEST_URI' => uri, 'rack.hijack' => -> {}} }

  subject { described_class.new(env, console, logger) }

  describe '#initialize' do
    before do
      allow(TCPSocket).to receive(:open) # prevent real sockets from opening
    end

    it 'sets the URL' do
      expect(subject.url).to eq("ws://#{host}#{uri}")
    end

    describe 'based on console type' do
      before do
        [WebsocketSocket, WebsocketWebmks, WebsocketWebmksUint8utf8].each do |k|
          allow(k).to receive(:new).and_return(k.allocate)
        end
      end

      let(:proxy)      { described_class.new(env, FactoryGirl.create(:system_console, :protocol => console_type), logger) }
      let(:proto)      { proxy.instance_variable_get(:@driver).instance_variable_get(:@options)[:protocols] }
      let(:adapter)    { proxy.instance_variable_get(:@right) }
      let(:on_message) { proxy.instance_variable_get(:@driver).listeners(:message).first }
      let(:right)      { double('right socket') }

      context 'when vnc' do
        let(:console_type) { 'vnc' }

        it 'uses binary protocol' do
          expect(proto).to eq(['binary'])
        end

        it 'uses WebsocketSocket adapter' do
          expect(adapter).to be_an_instance_of(WebsocketSocket)
        end

        it 'decodes message' do
          assert_message_transformation('BANANA'.unpack('C*'), 'BANANA')
        end
      end

      context 'when spice' do
        let(:console_type) { 'spice' }

        it 'uses binary protocol' do
          expect(proto).to eq(['binary'])
        end

        it 'uses WebsocketSocket adapter' do
          expect(adapter).to be_an_instance_of(WebsocketSocket)
        end

        it 'decodes message' do
          assert_message_transformation('BANANA'.unpack('C*'), 'BANANA')
        end
      end

      context 'when webmks' do
        let(:console_type) { 'webmks' }

        it 'uses binary protocol' do
          expect(proto).to eq(['binary'])
        end

        it 'uses WebsocketWebmks adapter' do
          expect(adapter).to be_an_instance_of(WebsocketWebmks)
        end

        it 'decodes message' do
          assert_message_transformation('BANANA'.unpack('C*'), 'BANANA')
        end
      end

      context 'when webmks-uint8utf8' do
        let(:console_type) { 'webmks-uint8utf8' }

        it 'uses uint8utf8 protocol' do
          expect(proto).to eq(['uint8utf8'])
        end

        it 'uses WebsocketWebmksUint8utf8 adapter' do
          expect(adapter).to be_an_instance_of(WebsocketWebmksUint8utf8)
        end

        it 'does not decode message' do
          assert_message_transformation('BANANA', 'BANANA')
        end
      end
    end
  end

  def assert_message_transformation(input, output)
    proxy.instance_variable_set(:@right, right)
    expect(right).to receive(:issue).with(output)
    on_message.call(double('message', :data => input))
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

    before do
      subject.instance_variable_set(:@driver, driver)
      subject.instance_variable_set(:@ws, ws)
      subject.instance_variable_set(:@sock, sock)
      right = subject.instance_variable_get(:@right)
      right.instance_variable_set(:@sock, sock)
    end

    context 'websocket to socket' do
      let(:is_ws) { true }

      it 'reads from the websocket and parses the result' do
        expect(ws).to receive(:recv_nonblock).and_return(123)
        expect(driver).to receive(:parse).with(123)

        subject.transmit([ws], is_ws)
      end
    end

    context 'socket to websocket' do
      let(:is_ws) { false }

      context 'binary' do
        it 'reads from the socket and sends the result to the driver' do
          expect(sock).to receive(:recv_nonblock).and_return(123)
          expect(driver).to receive(:binary).with(123)

          subject.transmit([sock], is_ws)
        end
      end

      context 'non-binary' do
        it 'reads from the socket and sends the result to the driver' do
          allow(subject).to receive(:binary?).and_return(false)
          expect(sock).to receive(:recv_nonblock).and_return(123)
          expect(driver).to receive(:frame).with(123)

          subject.transmit([sock], is_ws)
        end
      end
    end
  end
end
