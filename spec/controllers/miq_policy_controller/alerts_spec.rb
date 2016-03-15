describe MiqPolicyController do
  context "::Alerts" do
    before do
      login_as FactoryGirl.create(:user, :features => "alert_admin")
    end

    context "#alert_build_edit_screen" do
      before :each do
        @miq_alert = FactoryGirl.create(:miq_alert)
        controller.instance_variable_set(:@sb,
                                         :trees       => {:alert_tree => {:active_node => "al-#{@miq_alert.id}"}},
                                         :active_tree => :alert_tree
        )
      end

      it "it should skip id when copying all attributes of an existing alert" do
        controller.instance_variable_set(:@_params, :id => @miq_alert.id, :copy => "copy")
        controller.send(:alert_build_edit_screen)
        expect(assigns(:alert).id).to eq(nil)
      end

      it "it should select correct record when editing an existing alert" do
        controller.instance_variable_set(:@_params, :id => @miq_alert.id)
        controller.send(:alert_build_edit_screen)
        expect(assigns(:alert).id).to eq(@miq_alert.id)
      end
    end
  end
end
