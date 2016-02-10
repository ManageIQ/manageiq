describe MiqPolicyController do
  context "::AlertProfiles" do
    before do
      login_as FactoryGirl.create(:user, :features => "alert_profile_assign")
    end

    context "#alert_profile_assign" do
      before :each do
        @ap = FactoryGirl.create(:miq_alert_set)
        controller.instance_variable_set(:@sb, :trees => {:alert_profile_tree => {:active_node => "xx-Vm_ap-#{@ap.id}"}}, :active_tree => :alert_profile_tree)
        allow(controller).to receive(:replace_right_cell)
      end

      it "first time in" do
        expect(controller).to receive(:alert_profile_build_assign_screen)
        controller.alert_profile_assign
        expect(controller.send(:flash_errors?)).not_to be_truthy
      end

      it "Test reset button" do
        controller.instance_variable_set(:@_params, :id => @ap.id, :button => "reset")
        expect(controller).to receive(:alert_profile_build_assign_screen)
        controller.alert_profile_assign
        expect(assigns(:flash_array).first[:message]).to include("reset")
        expect(controller.send(:flash_errors?)).not_to be_truthy
      end

      it "Test cancel button" do
        controller.instance_variable_set(:@_params, :id => @ap.id, :button => "cancel")
        controller.alert_profile_assign
        expect(assigns(:flash_array).first[:message]).to include("cancelled")
        expect(controller.send(:flash_errors?)).not_to be_truthy
      end

      it "Test save button without selecting category" do
        controller.instance_variable_set(:@_params, {:id => @ap.id, :button => "save"})
        controller.instance_variable_set(:@sb, :trees => {:alert_profile_tree => {:active_node => "xx-Vm_ap-#{@ap.id}"}}, :active_tree => :alert_profile_tree,
                                                :assign => {:alert_profile => @ap, :new => {:assign_to => "Vm-tags", :objects => ["10000000000001"]}})
        controller.alert_profile_assign
        expect(assigns(:flash_array).first[:message]).not_to include("saved")
        expect(controller.send(:flash_errors?)).to be_truthy
      end

      it "Test save button with no errors" do
        controller.instance_variable_set(:@_params, {:id => @ap.id, :button => "save"})
        controller.instance_variable_set(:@sb, :trees => {:alert_profile_tree => {:active_node => "xx-Vm_ap-#{@ap.id}"}}, :active_tree => :alert_profile_tree,
                                                :assign => {:alert_profile => @ap, :new => {:assign_to => "Vm-tags", :cat => "10000000000001", :objects => ["10000000000001"]}})
        controller.alert_profile_assign
        expect(assigns(:flash_array).first[:message]).to include("saved")
        expect(controller.send(:flash_errors?)).not_to be_truthy
      end
    end
  end
end
