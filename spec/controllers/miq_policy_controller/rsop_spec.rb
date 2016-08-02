describe MiqPolicyController do
  render_views
  before :each do
    EvmSpecHelper.local_miq_server
    stub_user(:features => :all)
  end

  context "#rsop" do
    it "first time on RSOP screen, session[:changed] should be false" do
      session[:changed] = true
      controller.instance_variable_set(:@current_user,
                                       FactoryGirl.create(:user,
                                                          :name       => "foo",
                                                          :miq_groups => [],
                                                          :userid     => "foo"))
      controller.instance_variable_set(:@sb, {})
      allow(controller).to receive(:rsop_put_objects_in_sb)
      allow(controller).to receive(:find_filtered)
      allow(controller).to receive(:appliance_name)
      get :rsop
      expect(response.status).to eq(200)
      expect(session[:changed]).to be_falsey
      expect(response).to render_template('miq_policy/rsop')
    end
  end
end
