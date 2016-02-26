describe FlavorController do
  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @user = FactoryGirl.create(:user)
      login_as @user
      @flavor = FactoryGirl.create(:flavor)
    end
    subject { get :show, :id => @flavor.id }

    context "render listnav partial" do
      render_views
      it { is_expected.to have_http_status 200 }
      it { is_expected.to render_template(:partial => "layouts/listnav/_flavor") }
    end
  end
end
