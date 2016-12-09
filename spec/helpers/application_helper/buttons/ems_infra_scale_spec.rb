describe ApplicationHelper::Button::EmsInfraScale do
  let(:record) { FactoryGirl.create(:ems_openstack_infra) }
  let(:button) { described_class.new(setup_view_context_with_sandbox({}), {}, {'record' => record}, {}) }

  describe '#visible?' do
    subject { button.visible? }

    context 'when record is OpenStack Provider' do
      context 'and orchestration stack is empty' do
        it { expect(subject).to be_falsey }
      end
      context 'and orchestration stack is not empty' do
        let(:record) { FactoryGirl.create(:ems_openstack_infra_with_stack) }
        it { expect(subject).to be_truthy }
      end
    end
    context 'when record is not an OpenStack provider' do
      let(:record) { :ems_redhat }
      it { expect(subject).to be_falsey }
    end
  end
end
