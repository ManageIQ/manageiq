describe ApplicationHelper::Button::GenericFeatureButton do
  describe '#skip?' do
    [:pause].each do |feature|
      context "when instance supports feature #{feature}" do
        before do
          @record = FactoryGirl.create(:vm_openstack)
          allow(@record).to receive(:is_available?).with(feature).and_return(true)
        end

        it "will not be skipped for this instance" do
           view_context = setup_view_context_with_sandbox({})
           button = described_class.new(view_context, {}, {'record' => @record}, {:options => {:feature => feature}})
           expect(button.skip?).to be_falsey
        end
      end

      context "when instance does not support feature #{feature}" do
        before do
          @record = FactoryGirl.create(:vm_openstack)
          allow(@record).to receive(:is_available?).with(feature).and_return(false)
        end

        it "will be skipped for this instance" do
           view_context = setup_view_context_with_sandbox({})
           button = described_class.new(view_context, {}, {'record' => @record}, {:options => {:feature => feature}})
           expect(button.skip?).to be_truthy
        end
      end
    end
  end
end
