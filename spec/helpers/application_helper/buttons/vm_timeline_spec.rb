describe ApplicationHelper::Button::VmTimeline do
  let(:record) { FactoryGirl.create(:vm) }
  let(:button) { described_class.new(setup_view_context_with_sandbox({}), {}, {'record' => record}, {}) }

  describe '#calculate_properties' do
    it_behaves_like 'timeline#calculate_properties', 'No Timeline data has been collected for this VM'
  end
end
