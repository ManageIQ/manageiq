describe ApplicationHelper::Button::AbGroupReorder do
  subject { described_class.new(view_context, {}, {}, {:options => {:action => 'edited'}}) }

  describe '#disabled?' do
    context 'when :active_tree == :ab_tree' do
      let(:view_context) { setup_view_context_with_sandbox(:active_tree => :ab_tree) }

      before do
        custom_button_sets_count.times do
          FactoryGirl.create(:custom_button_set, :set_data => {:applies_to_class => cb_class})
        end
        allow(view_context).to receive(:x_node).and_return("xx-ab_#{cb_class}")
      end

      context 'and it is the only button in its class' do
        let(:cb_class) { 'tc-1' }
        let(:custom_button_sets_count) { 1 }
        it { expect(subject.disabled?).to be_truthy }
      end
      context 'and there are at least 2 button sets of the same class' do
        let(:cb_class) { 'tc-2' }
        let(:custom_button_sets_count) { 2 }
        it { expect(subject.disabled?).to be_falsey }
      end
    end

    context 'when :active_tree != :ab_tree' do
      let(:view_context) { setup_view_context_with_sandbox(:active_tree => :not_ab_tree) }
      let(:cb_class) { 'ServiceTemplate' }
      let(:service_template) { FactoryGirl.create(:service_template, :custom_button_sets => custom_button_sets) }
      let(:custom_button_sets) do
        (1..custom_button_sets_count).inject([]) do |arr|
          arr << FactoryGirl.create(:custom_button_set)
        end
      end

      before { allow(view_context).to receive(:x_node).and_return("xx-ab_#{cb_class}-#{service_template.id}") }

      context 'and there is only one button or button set present in the service template record' do
        let(:custom_button_sets_count) { 1 }
        it { expect(subject.disabled?).to be_truthy }
      end
      context 'and there are at least 2 button sets or buttons present in the service template record' do
        let(:custom_button_sets_count) { 2 }
        it { expect(subject.disabled?).to be_falsey }
      end
    end
  end
end
