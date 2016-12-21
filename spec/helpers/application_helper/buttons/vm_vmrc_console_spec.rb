describe ApplicationHelper::Button::VmVmrcConsole do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  let(:record) { FactoryGirl.create(:vm_vmware) }
  let(:button) { described_class.new(view_context, {}, {'record' => record}, {}) }

  describe '#visible?' do
    it_behaves_like 'vm_console_visible?', 'VMRC'
  end

  describe '#calculate_properties' do
    it_behaves_like 'vm_console_calculate_properties' do
      context 'when browser and os are supported and record.current_state == on' do
        let(:browser) { 'chrome' }
        let(:os) { 'linux' }
        let(:power_state) { 'on' }
        context 'and remote control is supported' do
          it_behaves_like 'an enabled button'
        end
        context 'and remote control is not supported' do
          let(:err_msg) { 'Remote console is not supported' }
          before do
            allow(record).to receive(:validate_remote_console_vmrc_support)
              .and_raise(MiqException::RemoteConsoleNotSupportedError, err_msg)
          end
          it do
            button[:enabled] = nil
            button.calculate_properties
            expect(button[:enabled]).to be_falsey
            is_expected.to eq("VM VMRC Console error: #{err_msg}")
          end
        end
      end
    end
  end
end
