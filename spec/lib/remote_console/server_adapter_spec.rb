RSpec.describe RemoteConsole::ServerAdapter do
  describe '.new' do
    let(:record) { FactoryBot.create(:system_console, :protocol => protocol) }

    context 'legacy vcloud console' do
      let(:protocol) { 'webmks-uint8utf8' }

      it 'calls the legacy websocket adapter' do
        expect(RemoteConsole::ServerAdapter::WebsocketUint8Utf8).to receive(:new).with({}, nil)

        described_class.new(record, {}, nil)
      end
    end

    context 'standard websocket' do
      let(:protocol) { 'vnc' }

      it 'calls the standard websocket adapter' do
        expect(RemoteConsole::ServerAdapter::WebsocketBinary).to receive(:new).with({}, nil)

        described_class.new(record, {}, nil)
      end
    end
  end
end
