RSpec.describe InfraConversionJob::Dispatcher do
  let(:zone) { FactoryBot.create(:zone) }
  let(:dispatcher) do
    described_class.new.tap do |dispatcher|
      dispatcher.instance_variable_set(:@zone_name, zone.name)
    end
  end

  before do
    @server = EvmSpecHelper.local_miq_server(:name => "test_server_main_server", :zone => zone)
  end

  describe '.waiting?' do
    let(:infra_conversion_job) { InfraConversionJob.create_job }

    it 'returns true if InfraConversionJob state is waiting_to_start' do
      infra_conversion_job.update!(:state => 'waiting_to_start')
      expect(described_class.waiting?).to be_truthy
    end

    it 'returns true if InfraConversionJob state is restoring_vm_attributes' do
      infra_conversion_job.update!(:state => 'restoring_vm_attributes')
      expect(described_class.waiting?).to be_truthy
    end

    it 'returns false if no InfraConversionJob state is finished' do
      infra_conversion_job.update!(:state => 'restoring_vm_attributes')
      expect(described_class.waiting?).to be_falsey
    end
  end
end
