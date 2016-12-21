describe ApplicationHelper::Button::OntapLogicalDiskPerf do
  let(:record) { FactoryGirl.create(:ontap_logical_disk) }
  let(:button) { described_class.new(setup_view_context_with_sandbox({}), {}, {'record' => record}, {}) }

  before { allow(record).to receive(:has_perf_data?).and_return(has_perf_data) }

  describe '#calculate_properties' do
    subject { button[:title] }
    before { button.calculate_properties }

    context 'when record has performance data' do
      let(:has_perf_data) { true }
      it { expect(button.disabled?).to be_falsey }
      it { expect(subject).to be_nil }
    end
    context 'when record does not have performance data' do
      let(:has_perf_data) { false }
      it { expect(button.disabled?).to be_truthy }
      it { expect(subject).to eq('No Capacity & Utilization data has been collected for this Logical Disk') }
    end
  end
end
