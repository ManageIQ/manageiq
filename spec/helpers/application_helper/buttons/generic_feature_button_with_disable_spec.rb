describe ApplicationHelper::Button::GenericFeatureButtonWithDisable do
  [:start, :stop, :suspend, :reset].each do |feature|
    describe '#skip?' do
      context "when vm supports feature #{feature}" do
        before do
          @record = FactoryGirl.create(:vm_vmware)
          allow(@record).to receive(:is_available?).with(feature).and_return(true)
        end

        it "will not be skipped for this vm" do
          view_context = setup_view_context_with_sandbox({})
          button = described_class.new(view_context, {}, {'record' => @record}, {:options => {:feature => feature}})
          expect(button.skip?).to be_falsey
        end
      end

      context "when instance does not support feature #{feature}" do
        before do
          @record = FactoryGirl.create(:vm_vmware)
          allow(@record).to receive(:is_available?).with(feature).and_return(false)
        end

        it "will be skipped for this vm" do
          view_context = setup_view_context_with_sandbox({})
          button = described_class.new(view_context, {}, {'record' => @record}, {:options => {:feature => feature}})
          expect(button.skip?).to be_truthy
        end
      end
    end
    describe '#disabled?' do
      context "when record has an error message" do
        before do
          @record = FactoryGirl.create(:vm_vmware)
          message = "xx stop message"
          allow(@record).to receive(:is_available_now_error_message).with(feature).and_return(message)
        end

        it "disables the button and returns the stop error message" do
          view_context = setup_view_context_with_sandbox({})
          button = described_class.new(view_context, {}, {'record' => @record}, {:options => {:feature => feature}})
          expect(button.disabled?).to be_truthy
        end
      end
    end
  end
end
