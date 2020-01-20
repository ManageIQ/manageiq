RSpec.describe RemoteConsole::ClientAdapter::WebMKS do
  let(:record) { FactoryBot.create(:system_console, :secret => '12345') }
  subject { described_class.new(record, nil) }

  before do
    ssl = double
    allow(OpenSSL::SSL::SSLSocket).to receive(:new).and_return(ssl)
    allow(OpenSSL::X509::Certificate).to receive(:new)
    allow(OpenSSL::PKey::RSA).to receive(:new)
    allow(File).to receive(:open)
    allow(ssl).to receive(:sync_close=)
    allow(ssl).to receive(:connect)

    driver = double
    allow(WebSocket::Driver).to receive(:client).and_return(driver)
    allow(driver).to receive(:start)
    allow(driver).to receive(:on)
  end

  describe '#path' do
    it 'returns with ticket/secret' do
      expect(subject.send(:path)).to eq('/ticket/12345')
    end
  end
end
