describe OpsController do
  context "::User" do
    user = User.all.first ? User.all.first : FactoryGirl.create(:user)
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      MiqRegion.seed
      set_user_privileges(user)
    end
    describe "#toolbars buttons tests" do
      it "add new user" do
        allow_any_instance_of(OpsController).to receive(:extra_js_commands)
        post :x_button, :pressed => "rbac_user_add"
        expect(response.status).to eq(200)
      end
      it "delete user" do
        allow_any_instance_of(OpsController).to receive(:extra_js_commands)
        post :x_button, :pressed => "rbac_user_delete", :id => user.id
        expect(response.status).to eq(200)
      end
      it "edit user" do
        allow_any_instance_of(OpsController).to receive(:extra_js_commands)
        post :x_button, :pressed => "rbac_user_edit", :id => user.id
        expect(response.status).to eq(200)
      end
      it "copy user" do
        allow_any_instance_of(OpsController).to receive(:extra_js_commands)
        post :x_button, :pressed => "rbac_user_copy", :id => user.id
        expect(response.status).to eq(200)
      end
    end
  end
end
