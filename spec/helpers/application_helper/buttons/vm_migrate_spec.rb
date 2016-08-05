describe ApplicationHelper::Button::VmMigrate do
  describe '#skip?' do
    context "when record is migrateable" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:supports_migrate?).and_return(true)
      end

      it_behaves_like "will not be skipped for this record"
    end

    context "when record is not migrateable" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:supports_migrate?).and_return(false)
      end

      it_behaves_like "will be skipped for this record"
    end
  end
end
