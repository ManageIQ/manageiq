shared_examples_for 'timeline#calculate_properties' do |err_msg|
  subject { button[:title] }
  before do
    allow(record).to receive(:has_events?).and_return(has_events)
    button.calculate_properties
  end

  %i(ems_events policy_events).each do |event_type|
    context "record has #{event_type}" do
      let(:has_events) { true }
      it do
        expect(button[:enabled]).to be_truthy
        is_expected.to be_nil
      end
    end
  end
  context 'record has no ems_events or policy_events' do
    let(:has_events) { false }
    it do
      expect(button[:enabled]).to be_falsey
      is_expected.to eq(err_msg)
    end
  end
end
