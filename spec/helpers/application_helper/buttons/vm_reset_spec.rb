require "spec_helper"

describe ApplicationHelper::Button::VmReset do
  describe '#skip?' do
    context "when record is resetable" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:is_available?).with(:reset).and_return(true)
      end

      it_behaves_like "will not be skipped for this record"
    end

    context "when record is not resetable" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:is_available?).with(:reset).and_return(false)
      end

      it_behaves_like "will be skipped for this record"
    end
  end

  describe '#disabled?' do
    context "when record has an error message" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        message = "xx reset message"
        allow(@record).to receive(:is_available_now_error_message).with(:reset).and_return(message)
      end

      it "disables the button" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.disabled?).to be_truthy
      end
    end
  end
end
