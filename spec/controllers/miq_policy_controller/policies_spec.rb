describe MiqPolicyController do
  before :each do
    set_user_privileges
  end
  context "::Policies" do
    context "#policy_edit" do
      before :each do
        event = FactoryGirl.create(:miq_event_definition, :name => "host_compliance_check")
        action = FactoryGirl.create(:miq_action, :name => "compliance_failed")
        allow(controller).to receive(:policy_get_node_info)
        allow(controller).to receive(:get_node_info)
        allow(controller).to receive(:replace_right_cell)
      end

      it "Correct active tree node is saved in @sb after Policy is added" do
        new = {}
        new[:mode] = "compliance"
        new[:towhat] = "Host"
        new[:description] = "Test_description"
        new[:expression] =  {">" => {"count" => "Host.advanced_settings", "value" => "1"}}
        controller.instance_variable_set(:@edit, {:new     => new,
                                                  :current => new,
                                                  :typ     => "basic",
                                                  :key     => "policy_edit__new"})
        session[:edit] = assigns(:edit)
        active_node = "xx-compliance_xx-compliance-host"
        controller.instance_variable_set(:@sb, {:trees       => {:policy_tree => {:active_node => active_node}},
                                                :active_tree => :policy_tree})
        controller.instance_variable_set(:@_params, :button => "add")
        controller.policy_edit
        sb = assigns(:sb)
        expect(sb[:trees][sb[:active_tree]][:active_node]).to include("#{active_node}_p-")
        expect(assigns(:flash_array).first[:message]).to include("added")
      end
    end
  end
end
