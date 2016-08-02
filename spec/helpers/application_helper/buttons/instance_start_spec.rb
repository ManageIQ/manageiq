require "spec_helper"

describe ApplicationHelper::Button::InstanceStart do
  describe '#skip?' do
    context "when record is stopable" do
      before do
        @record = FactoryGirl.create(:vm_openstack)
        allow(@record).to receive(:is_available?).with(:start).and_return(true)
      end

      it_behaves_like "will not be skipped for this record"
    end

    context "when record is not stopable" do
      before do
        @record = FactoryGirl.create(:vm_openstack)
        allow(@record).to receive(:is_available?).with(:start).and_return(false)
      end

      it_behaves_like "will be skipped for this record"
    end

    context "when record has no error message" do
      before do
        @record = FactoryGirl.create(:vm_openstack)
        allow(@record).to receive(:is_available_now_error_message).and_return(false)
      end

      it_behaves_like "will not be skipped for this record"
    end
  end
end
