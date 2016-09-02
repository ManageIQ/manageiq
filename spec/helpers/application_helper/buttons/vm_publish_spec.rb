describe ApplicationHelper::Button::VmPublish do
  describe '#visible?' do
    it_behaves_like "when record is orphaned"
    it_behaves_like "when record is archived"

    context "when record is not cloneable and vendor is redhat" do
      before do
        @record = FactoryGirl.create(:vm_redhat)
      end

      it "will be skipped" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.visible?).to be_falsey
      end
    end

    context "when record is not cloneable and vendor is redhat" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:archived?).and_return(false)
      end

      it "will not be skipped" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.visible?).to be_truthy
      end
    end
  end
end
