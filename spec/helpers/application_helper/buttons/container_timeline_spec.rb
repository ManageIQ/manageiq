describe ApplicationHelper::Button::ContainerTimeline do
  let(:record) { FactoryGirl.create(:container) }
  subject do
    described_class.new(setup_view_context_with_sandbox({}), {}, {'record' => record},
                        {:options => {:entity => 'Container'}})
  end

  before { allow(record).to receive(:has_events?).and_return(has_events) }

  describe '#disabled?' do
    %i(ems_events policy_events).each do |event_type|
      context "record has #{event_type}" do
        let(:has_events) { true }
        it { expect(subject.disabled?).to be_falsey }
      end
    end
    context 'record has no ems_events or policy_events' do
      let(:has_events) { false }
      it { expect(subject.disabled?).to be_truthy }
    end
  end
end
