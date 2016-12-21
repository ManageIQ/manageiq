describe ApplicationHelper::Button::OntapLogicalDiskStatistics do
  let(:record) { FactoryGirl.create(:ontap_logical_disk) }
  let(:button) { described_class.new(setup_view_context_with_sandbox({}), {}, {'record' => record}, {}) }
  before { allow(record).to receive(:latest_derived_metrics).and_return(metrics) }

  describe '#calculate_properties' do
    subject { button[:title] }
    before { button.calculate_properties }

    context 'when record has metrics' do
      let(:metrics) { [double] }
      it { expect(button.disabled?).to be_falsey }
      it { expect(subject).to be_nil }
    end
    context 'when record does not have metrics' do
      let(:metrics) { nil }
      it { expect(button.disabled?).to be_truthy }
      it { expect(subject).to eq('No Statistics collected for this Logical Disk') }
    end
  end
end
