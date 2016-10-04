describe ApplicationHelper::Button::VmInstanceTemplateScan do
  describe '#visible?' do
    context "when record has proxy and is not orphaned nor archived" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:has_proxy?).and_return(true)
        allow(@record).to receive(:archived?).and_return(false)
        allow(@record).to receive(:orphaned?).and_return(false)
      end

      it_behaves_like "will not be skipped for this record"
    end

    context "when record has no proxy and is not orphaned nor archived" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:has_proxy?).and_return(false)
        allow(@record).to receive(:archived?).and_return(false)
        allow(@record).to receive(:orphaned?).and_return(false)
      end

      it_behaves_like "will be skipped for this record"
    end

    context "when record has proxy and is not orphaned but archived" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:has_proxy?).and_return(true)
        allow(@record).to receive(:archived?).and_return(true)
        allow(@record).to receive(:orphaned?).and_return(false)
      end

      it_behaves_like "will be skipped for this record"
    end
  end

  describe '#disabled?' do
    context "when record has no active proxy and is not orphaned nor archived" do
      before do
        @record = FactoryGirl.create(:vm_vmware, :vendor => "vmware")
        allow(@record).to receive(:has_active_proxy?).and_return(false)
        allow(@record).to receive(:archived?).and_return(false)
        allow(@record).to receive(:orphaned?).and_return(false)
      end

      it "disables the button" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.disabled?).to be_truthy
      end
    end

    context "when record has active proxy and is not orphaned nor archived" do
      before do
        @record = FactoryGirl.create(:vm_vmware, :vendor => "vmware")
        allow(@record).to receive(:has_active_proxy?).and_return(true)
        allow(@record).to receive(:archived?).and_return(false)
        allow(@record).to receive(:orphaned?).and_return(false)
      end

      it "will not be disabled" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.disabled?).to be_falsey
      end
    end

    context "when record does not support smartstate_analysis" do
      before do
        @record = FactoryGirl.create(:vm_amazon, :vendor => "amazon")
        allow(@record).to receive(:has_active_proxy?).and_return(true)
        allow(@record).to receive(:supports_smartstate_analysis?).and_return(false)
        message = "xx smartstate_analysis message"
        allow(@record).to receive(:unsupported_reason).with(:smartstate_analysis).and_return(message)
      end

      it "disables the button" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.disabled?).to be_truthy
      end
    end
  end
end
