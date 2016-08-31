describe ApplicationHelper::Button::VmRefresh do
  describe '#visible?' do
    context "when record has ext_management_system and host vmm_product is workstation" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive_messages(:host => double(:vmm_product => "Workstation"),
                                           :ext_management_system => true)
      end

      it_behaves_like "will not be skipped for this record"
    end

    context "when record has no ext_management_system and host vmm_product is server" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive_messages(:host => double(:vmm_product => "Server"),
                                           :ext_management_system => false)
      end

      it_behaves_like "will be skipped for this record"
    end
  end
end
