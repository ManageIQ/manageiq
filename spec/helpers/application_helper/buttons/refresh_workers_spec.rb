describe ApplicationHelper::Button::RefreshWorkers do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  let(:record) { FactoryGirl.create(:miq_server) }

  describe '#visible?' do
    context 'when x_active_tree == diagnostics_tree and active_tab != diagnostics_workers' do
      it 'will be skipped' do
        button = described_class.new(view_context, {}, {'record' => record}, {})
        button.instance_variable_set(:@sb, :active_tab => 'does not matter')
        allow(view_context).to receive(:x_active_tree).and_return(:diagnostics_tree)
        expect(button.visible?).to be_falsey
      end
    end
    context 'when x_active_tree != diagnostics_tree and active_tab == diagnostics_workers' do
      it 'will be skipped' do
        button = described_class.new(view_context, {}, {'record' => record}, {})
        button.instance_variable_set(:@sb, :active_tab => 'diagnostics_workers')
        allow(view_context).to receive(:x_active_tree).and_return(:does_not_matter)
        expect(button.visible?).to be_falsey
      end
    end
    context 'when x_active_tree == diagnostics_tree and active_tab == diagnostics_workers' do
      it 'will not be skipped' do
        button = described_class.new(view_context, {}, {'record' => record}, {})
        button.instance_variable_set(:@sb, :active_tab => 'diagnostics_workers')
        allow(view_context).to receive(:x_active_tree).and_return(:diagnostics_tree)
        expect(button.visible?).to be_truthy
      end
    end
  end
end
