describe ApplicationHelper::Button::InstanceReset do
  describe '#skip?' do
    context "when record is resetable" do
      before do
        @record = FactoryGirl.create(:vm_openstack)
        allow(@record).to receive(:is_available?).with(:reset).and_return(true)
      end

      it_behaves_like "will not be skipped for this record"
    end

    context "when record is not resetable" do
      before do
        @record = FactoryGirl.create(:vm_openstack)
        allow(@record).to receive(:is_available?).with(:reset).and_return(false)
      end

      it_behaves_like "will be skipped for this record"
    end
  end
end
