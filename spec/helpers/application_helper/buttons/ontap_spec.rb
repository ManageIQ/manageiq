describe ApplicationHelper::Button::Ontap do
  let(:metrics) { nil }
  let(:type) { :ontap_storage_system }
  let(:record) { FactoryGirl.create(type) }
  let(:button) { described_class.new(setup_view_context_with_sandbox({}), {}, {'record' => record}, {}) }
  before { allow(record).to receive(:latest_derived_metrics).and_return(metrics) }

  describe '#visible?' do
    subject { button.visible? }
    before { stub_settings(:product => {:smis => smis}) }

    [true, false].each do |smis|
      context "when Settings.product.smis == #{smis}" do
        let(:smis) { smis }
        it { expect(subject).to eq(smis) }
      end
    end
  end

  describe '#calculate_properties' do
    subject { button[:title] }
    before { button.calculate_properties }

    %i(ontap_storage_system ontap_storage_volume ontap_file_share ontap_logical_disk).each do |record_type|
      context "when record's type is #{record_type}" do
        let(:type) { record_type }
        context 'when record has metrics' do
          let(:metrics) { [double] }
          it { expect(button.disabled?).to be_falsey }
          it { expect(subject).to be_nil }
        end
        context 'when records does not have metrics' do
          it { expect(button.disabled?).to be_truthy }
          it { expect(subject).to eq('No Statistics Collected') }
        end
      end
    end
  end
end
