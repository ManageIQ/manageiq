describe FlavorController do
  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      login_as FactoryGirl.create(:user)
      @flavor = FactoryGirl.create(:flavor)
      allow_any_instance_of(RequestRefererService).to receive(:referer_valid?).and_return(true)
    end
    subject { get :show, :params => {:id => @flavor.id} }

    context "render listnav partial" do
      render_views
      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_flavor")
      end
    end
  end
end
