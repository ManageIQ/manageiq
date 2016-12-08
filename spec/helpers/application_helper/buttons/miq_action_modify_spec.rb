describe ApplicationHelper::Button::MiqActionModify do
  let(:view_context) { setup_view_context_with_sandbox(:active_tree => tree) }
  let(:record) { FactoryGirl.create(:miq_event_definition) }
  let(:button) { described_class.new(view_context, {}, {'record' => record}, {}) }
  let(:tree) { :policy_tree }

  describe '#visible?' do
    subject { button.visible? }

    context 'when active_tree == :event_tree' do
      let(:tree) { :event_tree }
      it { expect(subject).to be_falsey }
    end
    context 'when active_tree == :policy_tree' do
      it { expect(subject).to be_truthy }
    end
  end

  describe '#disabled?' do
    subject { button.disabled? }
    before { allow(view_context).to receive(:x_node).and_return("p-#{policy.id}_ev-1") }

    context 'when policy is read_only' do
      let(:policy) { FactoryGirl.create(:miq_policy_read_only) }
      it { expect(subject).to be_truthy }
    end
    context 'when policy is not read-only' do
      let(:policy) { FactoryGirl.create(:miq_policy) }
      it { expect(subject).to be_falsey }
    end
  end

  describe '#calculate_properties' do
    let(:messages) do
      ['This Action belongs to a read only Policy and cannot be modified',
       'This Event belongs to a read only Policy and cannot be modified',
       nil]
    end
    let(:policy) { FactoryGirl.create(:miq_policy_read_only) }
    subject { button[:title] }

    before { allow(view_context).to receive(:x_node).and_return("p-#{policy.id}_#{type}-1") }
    before(:each) { button.calculate_properties }

    %w(a ev u).each_with_index do |type, i|
      context "when #{type} is active" do
        let(:type) { type }
        it { expect(subject).to eq(messages[i]) }
      end
    end
  end
end
