describe ApplicationHelper::Button::MiddlewareInstanceAdd do
  let(:server) { FactoryGirl.create(:middleware_server, :middleware_server_group => group) }
  subject { described_class.new(setup_view_context_with_sandbox({}), {}, {'record' => record}, {}) }

  describe '#visible?' do
    context 'when record responds to #in_domain?' do
      let(:record) { server }
      context 'when server.in_domain? == true' do
        let(:group) { FactoryGirl.create(:middleware_server_group) }
        it { expect(subject.visible?).to be_falsey }
      end
      context 'when server.in_domain? == false' do
        let(:group) { nil }
        it { expect(subject.visible?).to be_truthy }
      end
    end
    context 'when record does not respond to #in_domain?' do
      let(:record) { FactoryGirl.create(:middleware_deployment, :middleware_server => server) }
      context 'when server.in_domain? == true' do
        let(:group) { FactoryGirl.create(:middleware_server_group) }
        it { expect(subject.visible?).to be_falsey }
      end
      context 'when server.in_domain? == false' do
        let(:group) { nil }
        it { expect(subject.visible?).to be_truthy }
      end
    end
  end
end
