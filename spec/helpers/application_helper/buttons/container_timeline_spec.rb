describe ApplicationHelper::Button::ContainerTimeline do
  let(:record) { FactoryGirl.create(:container) }
  let(:button) do
    described_class.new(setup_view_context_with_sandbox({}), {}, {'record' => record},
                        {:options => {:entity => 'Container'}})
  end

  describe '#calculate_properties?' do
    it_behaves_like 'timeline#calculate_properties', 'No Timeline data has been collected for this Container'
  end
end
