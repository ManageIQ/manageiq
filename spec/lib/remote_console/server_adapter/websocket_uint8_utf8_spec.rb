RSpec.describe RemoteConsole::ServerAdapter::WebsocketUint8Utf8 do
  let(:env) do
    {
      'HTTP_HOST'       => 'localhost:3000',
      'REQUEST_URI'     => '/ws/console/test',
      'rack.url_scheme' => 'http'
    }
  end
  let(:sock) { instance_double(IO) }
  let(:driver) { instance_double(WebSocket::Driver::Server) }

  subject { described_class.new(env, sock) }

  before do
    allow(WebSocket::Driver).to receive(:rack).and_return(driver)
    allow(driver).to receive(:on)
    allow(driver).to receive(:start)
  end

  describe '#initialize' do
    it 'creates a websocket driver with uint8utf8 protocol' do
      expect(WebSocket::Driver).to receive(:rack).with(
        anything,
        hash_including(:protocols => ['uint8utf8'])
      ).and_return(driver)

      described_class.new(env, sock)
    end
  end

  describe '#fetch' do
    let(:text_data) { "console output text" }
    let(:websocket_frame) { "websocket_frame_data" }

    before do
      allow(sock).to receive(:read_nonblock).and_return(websocket_frame)
      allow(driver).to receive(:parse)
      allow(driver).to receive(:listeners).with(:message).and_return([])
    end

    it 'reads from socket and parses through driver' do
      expect(sock).to receive(:read_nonblock).with(1024).and_return(websocket_frame)
      expect(driver).to receive(:parse).with(websocket_frame)

      subject.fetch(1024) { |_data| nil }
    end

    it 'yields data directly from websocket-driver' do
      # For uint8utf8 protocol, data is used directly without transformation
      allow(driver).to receive(:on).with(:message) do |&block|
        msg = double('message', :data => text_data)
        block.call(msg)
      end

      yielded_data = nil
      subject.fetch(1024) { |data| yielded_data = data }

      expect(yielded_data).to eq(text_data)
    end

    it 'only sets up message callback once' do
      # First call sets up the callback (listeners returns empty array)
      allow(driver).to receive(:listeners).with(:message).and_return([])
      subject.fetch(1024) { |_data| nil }

      # Second call should not set up callback again (listeners returns non-empty array)
      allow(driver).to receive(:listeners).with(:message).and_return([double])
      expect(driver).not_to receive(:on).with(:message)
      subject.fetch(1024) { |_data| nil }
    end
  end

  describe '#issue' do
    it 'sends data through driver frame method' do
      data = "text to send"
      expect(driver).to receive(:frame).with(data)

      subject.issue(data)
    end
  end

  describe '#write' do
    it 'writes data to socket' do
      data = "frame_data"
      expect(sock).to receive(:write_nonblock).with(data)

      subject.write(data)
    end
  end
end
