describe ApplicationHelper::Button::HostRegisterNodes do
  let(:record) { FactoryGirl.create(:ems_openstack_infra) }
  let(:button) { described_class.new(setup_view_context_with_sandbox({}), {}, {'record' => record}, {}) }

  describe '#visible?' do
    subject { button.visible? }

    context 'when record.class == ManageIQ::Providers::Openstack::InfraManager' do
      it { expect(subject).to be_truthy }
    end
    context 'when recor.class != ManageIQ::Providers::Openstack::InfraManager' do
      let(:record) { FactoryGirl.create(:host_openstack_infra) }
    end
  end
end
