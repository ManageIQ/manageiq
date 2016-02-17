describe OpsController do
  context "#toolbar buttons tests" do
    before(:each) do
      set_user_privileges
      EvmSpecHelper.create_guid_miq_server_zone
      ApplicationController.handle_exceptions = true
    end

    it "add new zone" do
      allow_any_instance_of(OpsController).to receive(:extra_js_commands)
      post :x_button, :pressed => "zone_new"
      expect(response.status).to eq(200)
    end

    it "edit zone" do
      zone = FactoryGirl.create(:zone, :name => 'zone1')
      allow_any_instance_of(OpsController).to receive(:extra_js_commands)
      post :x_button, :pressed => "zone_edit", :id => zone.id
      expect(response.status).to eq(200)
    end

    it "delete zone" do
      MiqRegion.seed
      zone = FactoryGirl.create(:zone, :name => 'zone1')
      allow_any_instance_of(OpsController).to receive(:extra_js_commands)
      post :x_button, :pressed => "zone_delete", :id => zone.id
      expect(response.status).to eq(200)
    end
  end
end
