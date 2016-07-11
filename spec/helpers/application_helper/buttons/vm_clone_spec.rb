require "spec_helper"

describe ApplicationHelper::Button::VmClone do
  describe '#skip?' do
    it_behaves_like "when record is orphaned"
    it_behaves_like "when record is archived"

    context "when record is not cloneable" do
      before do
        @record = FactoryGirl.create(:vm_microsoft,
                                     :name => "vm",
                                     :location => "l2",
                                     :vendor => "microsoft")
      end

      it "will be skipped" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.skip?).to be_truthy
      end
    end

    context "when record is cloneable" do
      before do
        @record = FactoryGirl.create(:vm_vmware,
                                     :name => "rh",
                                     :location => "l1",
                                     :vendor => "redhat")
      end

      it "will not be skipped" do
        view_context = setup_view_context_with_sandbox({})
        allow(@record).to receive(:archived?).and_return(false)
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.skip?).to be_falsey
      end
    end
  end
end
