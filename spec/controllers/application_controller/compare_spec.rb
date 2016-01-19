describe ApplicationController do
  context "#drift_history" do
    it "resets @display to main" do
      vm = FactoryGirl.create(:vm_vmware, :name => "My VM")
      controller.instance_variable_set(:@display, "vms")
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@drift_obj, vm)
      allow(controller).to receive(:identify_obj)
      allow(controller).to receive(:drift_state_timestamps)
      allow(controller).to receive(:drop_breadcrumb)
      expect(controller).to receive(:render)
      controller.send(:drift_history)
      expect(assigns(:display)).to eq("main")
    end
  end
end
