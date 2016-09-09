describe ApplicationHelper::Button::VmRetire do
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
    context "button should not be disabled" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:retired).and_return(true)
      end

      it "does not disable the button" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.disabled?).to be_falsey
      end
    end
  end
end
