RSpec.describe FirmwareRegistry do
  before  { EvmSpecHelper.create_guid_miq_server_zone }
  subject { FactoryBot.create(:firmware_registry) }

  describe '#destroy' do
    let!(:binary) { FactoryBot.create(:firmware_binary, :with_endpoints, :firmware_registry => subject) }
    let!(:target) { FactoryBot.create(:firmware_target, :firmware_binaries => [binary]) }

    it 'deletes repository in cascade' do
      expect(FirmwareRegistry.count).to eq(1)
      expect(FirmwareBinary.count).to eq(1)
      expect(Authentication.count).to eq(1)
      expect(Endpoint.count).to eq(1 + 2) # registry endpoint + 2*binary endpoint
      expect(FirmwareBinaryFirmwareTarget.count).to eq(1)
      expect(FirmwareTarget.count).to eq(1)

      subject.destroy

      expect(FirmwareRegistry.count).to eq(0)
      expect(FirmwareBinary.count).to eq(0)
      expect(Endpoint.count).to eq(0)
      expect(Authentication.count).to eq(0)
      expect(FirmwareBinaryFirmwareTarget.count).to eq(0)
      expect(FirmwareTarget.count).to eq(1)
    end
  end

  it "doesn't access database when unchanged model is saved" do
    m = FactoryBot.create(:firmware_registry)
    expect { m.valid? }.not_to make_database_queries
  end

  it '#sync_fw_binaries_raw' do
    expect { subject.sync_fw_binaries_raw }.to raise_error(NotImplementedError)
  end

  it '#sync_fw_binaries_queue' do
    subject.sync_fw_binaries_queue
    expect(MiqQueue.count).to eq(1)
    expect(MiqQueue.find_by(:method_name => 'sync_fw_binaries')).to have_attributes(
      :class_name  => described_class.name,
      :instance_id => subject.id
    )
  end

  describe '#sync_fw_binaries' do
    context 'when sync succeeds' do
      before { allow(subject).to receive(:sync_fw_binaries_raw).and_return(nil) }

      it 'last_refresh_[on|error] is updated' do
        subject.sync_fw_binaries
        subject.reload
        expect(subject.last_refresh_error).to be_nil
        expect(subject.last_refresh_on).to be_within(5.seconds).of(Time.now.utc)
      end
    end

    context 'when sync errors' do
      before { allow(subject).to receive(:sync_fw_binaries_raw).and_raise(MiqException::Error.new('MESSAGE')) }

      it 'last_refresh_[on|error] is updated' do
        subject.sync_fw_binaries
        subject.reload
        expect(subject.last_refresh_error).to eq('MESSAGE')
        expect(subject.last_refresh_on).to be_within(5.seconds).of(Time.now.utc)
      end
    end
  end

  describe '.create_firmware_registry' do
    let(:registry) { double('registry') }
    it 'creates registry and triggers refresh' do
      expect(FirmwareRegistry::RestApiDepot).to receive(:validate_options) { |options| options }
      expect(FirmwareRegistry::RestApiDepot).to receive(:do_create_firmware_registry).with(:a => 'A').and_return(registry)
      expect(registry).to receive(:sync_fw_binaries_queue)
      described_class.create_firmware_registry(:type => 'FirmwareRegistry::RestApiDepot', :a => 'A')
    end
  end
end
