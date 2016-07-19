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

      it_behaves_like "will be skipped for this record"
    end

    context "when record is cloneable" do
      before do
        @record = FactoryGirl.create(:vm_vmware,
                                     :name => "rh",
                                     :location => "l1",
                                     :vendor => "redhat")
        allow(@record).to receive(:archived?).and_return(false)
      end

      it_behaves_like "will not be skipped for this record"
    end
  end
end
