describe AvailabilityZoneHelper do

  context "#accessible_select_event_types" do
    it 'returns only Management Events' do
      expect(accessible_select_event_types).to eq([['Management Events', 'timeline']])
    end
  end
end
