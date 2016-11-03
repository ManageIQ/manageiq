describe ApplicationHelper::Button::MiddlewareAction do
  subject { described_class.new(setup_view_context_with_sandbox({}), {}, {'record' => record}, {}) }

  describe '#visible?' do
    let(:record) { FactoryGirl.create(middleware, :product => product) }
    context 'when record respond_to?(:product)' do
      let(:middleware) { :middleware_server }
      context 'and product is Hawkular' do
        let(:product) { 'Hawkular' }
        it { expect(subject.visible?).to be_falsey }
      end
      context 'and product is not Hawkular' do
        let(:product) { nil }
        it { expect(subject.visible?).to be_truthy }
      end
    end
    context 'when record does not respond_to?(:product)' do
      let(:record) { FactoryGirl.create(:middleware_datasource, :middleware_server => server) }
      let(:server) { FactoryGirl.create(:middleware_server, :product => product) }
      context 'and its middleware server returns Hawkular' do
        let(:product) { 'Hawkular' }
        it { expect(subject.visible?).to be_falsey }
      end
      context 'and its middleware server does not return Hawkular' do
        let(:product) { nil }
        it { expect(subject.visible?).to be_truthy }
      end
    end
  end
end
