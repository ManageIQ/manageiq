require "spec_helper"

describe ApplicationHelper::Button::InstanceShelveOffload do
  describe '#skip?' do
    context "when record is shelve_offloadable" do
      before do
        @record = FactoryGirl.create(:vm_openstack)
        allow(@record).to receive(:is_available?).with(:shelve_offload).and_return(true)
      end

      it_behaves_like "will not be skipped for this record"
    end

    context "when record is not shelve_offloadable" do
      before do
        @record = FactoryGirl.create(:vm_openstack)
        allow(@record).to receive(:is_available?).with(:shelve_offload).and_return(false)
      end

      it_behaves_like "will be skipped for this record"
    end
  end
end
