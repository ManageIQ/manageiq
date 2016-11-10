describe ApplicationHelper::Button::AbGroupEdit do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject do
    described_class.new(
      view_context,
      {},
      {},
      {:child_id => 'ab_group_edit', :options => {:action => 'edited'}}
    )
  end

  before { allow(view_context).to receive(:x_node).and_return(x_node) }

  describe '#disabled?' do
    context 'when button group is unassigned' do
      let(:x_node) { 'xx-ub' }
      it { expect(subject.disabled?).to be_truthy }
    end
    context 'when button group is not unassigned' do
      let(:x_node) { 'xx-ab_12345' }
      it { expect(subject.disabled?).to be_falsey }
    end
  end
end
