RSpec.describe RemoteConsole::ClientAdapter do
  describe '.new' do
    let(:record) { FactoryBot.create(:system_console, :protocol => protocol, :ssl => ssl) }
    let(:ssl) { false }

    context 'VNC' do
      let(:protocol) { 'vnc' }

      it 'regular socket' do
        expect(RemoteConsole::ClientAdapter::RegularSocket).to receive(:new).with(record, nil)

        described_class.new(record, nil)
      end
    end

    context 'SPICE' do
      let(:protocol) { 'spice' }

      context 'SSL' do
        let(:ssl) { true }

        it 'ssl socket' do
          expect(RemoteConsole::ClientAdapter::SSLSocket).to receive(:new).with(record, nil)

          described_class.new(record, nil)
        end
      end

      it 'regular socket' do
        expect(RemoteConsole::ClientAdapter::RegularSocket).to receive(:new).with(record, nil)

        described_class.new(record, nil)
      end
    end

    context 'WebMKS' do
      let(:protocol) { 'webmks' }
      let(:ssl) { true }

      it 'webmks socket' do
        expect(RemoteConsole::ClientAdapter::WebMKS).to receive(:new).with(record, nil)

        described_class.new(record, nil)
      end

      context 'legacy' do
        let(:protocol) { 'webmks-uint8utf8' }

        it 'webmks legacy socket' do
          expect(RemoteConsole::ClientAdapter::WebMKSLegacy).to receive(:new).with(record, nil)

          described_class.new(record, nil)
        end
      end
    end
  end
end
