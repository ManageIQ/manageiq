describe ApplicationHelper::Button::VmRetireNow do
  describe '#visible?' do
    context "when record is retireable" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:supports_retire?).and_return(true)
      end

      it_behaves_like "will not be skipped for this record"
    end

    context "when record is not retiretable" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:supports_retire?).and_return(false)
      end

      it_behaves_like "will be skipped for this record"
    end
  end

  describe '#disabled?' do
    context "when record has an error message" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:retired).and_return(true)
      end

      it "disables the button" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.disabled?).to be_truthy
      end
    end
  end

  describe "#calculate_properties" do
    context "when record is retired" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:retired).and_return(true)
      end

      it "sets the error message for disabled button" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        button.calculate_properties
        expect(button[:title]).to eq("VM is already retired")
      end
    end
  end
end
