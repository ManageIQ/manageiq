require "spec_helper"

describe ApplicationHelper::Button::VmRefresh do
  describe '#skip?' do
    context "when record has ext_management_system and host vmm_product is workstation" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive_messages(:host => double(:vmm_product => "Workstation"), :ext_management_system => true)
      end

      it "will not be skipped" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.skip?).to be_falsey
      end
    end

    context "when record has no ext_management_system and host vmm_product is server" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive_messages(:host => double(:vmm_product => "Server"), :ext_management_system => false)
      end

      it "will be skipped" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record}, {})
        expect(button.skip?).to be_truthy
      end
    end
  end
end
