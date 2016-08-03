require "spec_helper"

describe ApplicationHelper::Button::InstanceStop do
  describe '#skip?' do
    context "when record is stopable" do
      before do
        @record = FactoryGirl.create(:vm_openstack)
        allow(@record).to receive(:is_available?).with(:stop).and_return(true)
      end

      it_behaves_like "will not be skipped for this record"
    end

    context "when record is not stopable" do
      before do
        @record = FactoryGirl.create(:vm_openstack)
        allow(@record).to receive(:is_available?).with(:stop).and_return(false)
      end

      it_behaves_like "will be skipped for this record"
    end
  end
end
