describe ApplicationHelper::Button::FloatingIpNew do
  describe '#disabled?' do
    it "when at least one provider supports floating ip create then the button is not disabled" do
      view_context = setup_view_context_with_sandbox({})
      FactoryGirl.create(:ems_openstack)
      button = described_class.new(view_context, {}, {}, {})
      expect(button.disabled?).to be false
    end

    it "when no provider supports floating ip create then the button is disabled" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(view_context, {}, {}, {})
      expect(button.disabled?).to be true
    end
  end

  describe '#calculate_properties' do
    it "when no provider supports floating ip create the button has an error in the title" do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(view_context, {}, {}, {})
      button.calculate_properties
      expect(button[:title]).to eq("No cloud providers support creating floating IPs.")
    end

    it "when at least one provider supports floating ip create, the button has no error in the title" do
      view_context = setup_view_context_with_sandbox({})
      FactoryGirl.create(:ems_openstack)
      button = described_class.new(view_context, {}, {}, {})
      button.calculate_properties
      expect(button[:title]).to be nil
    end
  end
end
