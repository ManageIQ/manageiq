shared_examples 'vm_console_record_types' do |supported_records|
  supported_records.each do |type, support|
    context "and record is type of #{type}" do
      let(:record) { FactoryGirl.create(type) }
      it { is_expected.to eq(support) }
    end
  end
end

shared_examples 'vm_console_with_power_state_on_off' do |err_msg|
  context 'and record.current_state == on' do
    let(:power_state) { 'on' }
    it_behaves_like 'an enabled button'
  end
  context 'and record.current_state == off' do
    let(:power_state) { 'off' }
    it_behaves_like 'a disabled button',
                    err_msg || 'The web-based console is not available because the VM is not powered on'
  end
end

shared_examples_for 'vm_console_visible?' do |console_type, records|
  let(:remote_console_type) { console_type }
  subject { button.visible? }
  before { stub_settings(:server => {:remote_console_type => remote_console_type}) }

  context "when console supports #{console_type}" do
    it_behaves_like 'vm_console_record_types',
                    records || {:vm_openstack => false, :vm_redhat => false, :vm_vmware => true}
  end
  context "when console does not support #{console_type}" do
    let(:remote_console_type) { "NOT_#{console_type}" }
    it { is_expected.to be_falsey }
  end
end

shared_examples_for 'vm_console_calculate_properties' do
  let(:browser) { 'safari' }
  let(:os) { 'macOS' }
  let(:power_state) { 'on' }
  subject { button[:title] }

  before do
    allow(view_context).to receive_message_chain(:session, :fetch_path).with(:browser, :name).and_return(browser)
    allow(view_context).to receive_message_chain(:session, :fetch_path).with(:browser, :os).and_return(os)
    allow(record).to receive(:validate_remote_console_vmrc_support).and_return(true)
    allow(record).to receive(:current_state).and_return(power_state)
  end
  before(:example) { button.calculate_properties }

  shared_examples 'no_support' do
    it_behaves_like 'a disabled button',
                    'The web-based console is only available on IE, Firefox or Chrome (Windows/Linux)'
  end

  %w(explorer firefox mozilla chrome).each do |browser|
    context "when browser is #{browser}" do
      let(:browser) { browser }
      %w(windows linux).each do |os|
        context "and os is #{os}" do
          let(:os) { os }
          it_behaves_like 'vm_console_with_power_state_on_off'
        end
      end
      context 'and os is not supported' do
        it_behaves_like 'no_support'
      end
    end
  end
  context 'when browser is not supported' do
    it_behaves_like 'no_support'
  end
end
