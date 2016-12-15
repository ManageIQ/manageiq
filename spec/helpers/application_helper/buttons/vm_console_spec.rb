describe ApplicationHelper::Button::VmConsole do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  let(:record) { FactoryGirl.create(:vm) }
  let(:button) { described_class.new(view_context, {}, {'record' => record}, {}) }

  describe '#visible?' do
    it_behaves_like 'vm_console_visible?', 'MKS'
  end

  describe '#calculate_properties' do
    it_behaves_like 'vm_console_calculate_properties'
  end
end
