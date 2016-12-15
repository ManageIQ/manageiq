describe ApplicationHelper::Button::HostManageable do
  let(:provision_state) { String.new 'not_manageable' }
  let(:record) { FactoryGirl.create(:host_openstack_infra, :with_hardware) }
  let(:button) { described_class.new(setup_view_context_with_sandbox({}), {}, {'record' => record}, {}) }

  before { allow(record.hardware).to receive(:provision_state).and_return(provision_state) }

  describe '#visible?' do
    subject { button.visible? }

    context 'when record.class == ManageIQ::Providers::Openstack::InfraManager::Host' do
      context 'and hardware.provision_state == manageable' do
        let(:provision_state) { String.new 'manageable' }
        it { expect(subject).to be_falsey }
      end
      context 'and hardware.provision_state != manageable' do
        it { expect(subject).to be_truthy }
      end
    end
    context 'when record type is not host_openstack_infra, nor ems_openstack_infra' do
      let(:record) { FactoryGirl.create(:host_vmware) }
      it { expect(subject).to be_falsey }
    end
  end
end
