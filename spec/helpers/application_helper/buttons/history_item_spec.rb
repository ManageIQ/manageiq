describe ApplicationHelper::Button::HistoryItem do
  let(:sandbox) do
    {:history     => {:testing => testing_history},
     :active_tree => :testing}
  end
  let(:view_context) { setup_view_context_with_sandbox(sandbox) }
  let(:button) { described_class.new(view_context, {}, {}, {:id => id}) }

  describe '#visible?' do
    let(:testing_history) { %w(some thing to test with) }
    subject { button.visible? }

    %w(1 2 3 4).each do |n|
      context "when with existing history_#{n}" do
        let(:id) { "history_#{n}".to_sym }
        it { expect(subject).to be_truthy }
      end
    end
    context 'when not history_1 and the tree history not exist' do
      let(:id) { :history_10 }
      it { expect(subject).to be_falsey }
    end
  end

  describe '#disabled?' do
    subject { button.disabled? }

    context 'when history_item_id == 1' do
      let(:id) { :history_1 }
      (0...2).each do |n|
        context "when x_tree_history.length == #{n}" do
          let(:testing_history) { [*0...n] }
          it { expect(subject).to be_truthy }
        end
      end
      (2..4).each do |n|
        context "when x_tree_history.length == #{n}" do
          let(:testing_history) { [*0...n] }
          it { expect(subject).to be_falsey }
        end
      end
    end
    context 'when history_item_id != 1' do
      let(:id) { :history_2 }
      let(:testing_history) { [nil] }
      it { expect(subject).to be_falsey }
    end
  end
end
