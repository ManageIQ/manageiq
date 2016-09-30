describe ApplicationHelper::Button::GenericFeatureButtonWithDisable do
  describe '#disabled?' do
    context "when record has an error message" do
      it "disables the button and returns the stop error message" do
        record = double
        message = "xx stop message"
        allow(record).to receive(:feature_known?).with(:some_feature).and_return(true)
        allow(record).to receive(:supports?).with(:some_feature).and_return(false)
        allow(record).to receive(:unsupported_reason).with(:some_feature).and_return(message)
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => record}, {:options => {:feature => :some_feature}})
        expect(button.disabled?).to be_truthy
        button.calculate_properties
        expect(button[:title]).to eq(message)
      end

      it "disables the button and returns the stop error message" do
        # TODO: remove with deleting AvailabilityMixin module
        record = double
        message = "xx stop message"
        allow(record).to receive(:feature_known?).with(:some_feature).and_return(false)
        allow(record).to receive(:is_available?).with(:some_feature).and_return(false)
        allow(record).to receive(:is_available_now_error_message).with(:some_feature).and_return(message)
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => record}, {:options => {:feature => :some_feature}})
        expect(button.disabled?).to be_truthy
        button.calculate_properties
        expect(button[:title]).to eq(message)
      end
    end
  end
end
