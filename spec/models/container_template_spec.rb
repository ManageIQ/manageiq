describe ContainerTemplate do
  describe "#generic_custom_buttons" do
    before do
      allow(CustomButton).to receive(:buttons_for).with("ContainerTemplate").and_return("this is a list of custom buttons")
    end

    it "returns all the custom buttons for container templates" do
      expect(ContainerTemplate.new.generic_custom_buttons).to eq("this is a list of custom buttons")
    end
  end
end
