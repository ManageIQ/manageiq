describe ApplicationHelper::Button::MiqActionModify do
  before(:each) do
    @record = FactoryGirl.create(:miq_event_definition)
    @layout = 'miq_policy'
  end

  describe '#visible?' do
    context 'when id == event_edit' do
      it 'hides toolbar in policy event tree' do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        button.instance_variable_set(:@sb, :active_tree => :event_tree)
        allow(view_context).to receive(:x_active_tree).and_return(:event_tree)
        allow(button).to receive(:role_allows?).and_return(true)
        expect(button.visible?).to be_falsey
      end

      it 'shows toolbar in policy tree' do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        button.instance_variable_set(:@sb, :active_tree => :policy_tree)
        allow(view_context).to receive(:x_active_tree).and_return(:policy_tree)
        allow(button).to receive(:role_allows?).and_return(true)
        expect(button.visible?).to be_truthy
      end
    end
  end

  describe '#disabled?' do
    context 'when id == event_edit' do
      it 'gets disabled if policy is read-only' do
        policy = FactoryGirl.create(:miq_policy_read_only)
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        allow(view_context).to receive(:x_node).and_return("p-#{policy.id}")
        button.instance_variable_set(:@sb, :active_tree => :policy_tree)
        expect(button.disabled?).to be_truthy
      end

      it 'is enabled if policy is not read-only' do
        policy = FactoryGirl.create(:miq_policy)
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        allow(view_context).to receive(:x_node).and_return("p-#{policy.id}")
        button.instance_variable_set(:@sb, :active_tree => :policy_tree)
        expect(button.disabled?).to be_falsey
      end
    end
  end

  describe '#calculate_properties' do
    context 'when id == event_edit' do
      messages = [
        'This Action belongs to a read only Policy and cannot be modified',
        'This Event belongs to a read only Policy and cannot be modified',
        nil
      ]
      %w(a ev u).each_with_index do |type, i|
        it "sets message for #{type} when #{type} is active" do
          view_context = setup_view_context_with_sandbox({})
          button = described_class.new(view_context, {}, {'record' => @record}, {})
          allow(button).to receive(:disabled?).and_return(true)
          allow(view_context).to receive(:x_node).and_return("#{type}-1")
          expect(button.calculate_properties).to eq(messages[i])
        end
      end
    end
  end
end
