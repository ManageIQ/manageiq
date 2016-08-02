require "spec_helper"

describe ApplicationHelper::Button::ServiceReconfigure do
  describe '#skip?' do
    context "when record is reconfigurable" do
      before do
        @record = FactoryGirl.create(:service)
        allow(@record).to receive(:validate_reconfigure).and_return(true)
      end

      it "will be not skipped" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.skip?).to be_falsey
      end
    end

    context "when record is not reconfigurable" do
      before do
        @record = FactoryGirl.create(:service)
        allow(@record).to receive(:validate_reconfigure).and_return(false)
      end

      it "will be skipped" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.skip?).to be_truthy
      end
    end
  end
end
