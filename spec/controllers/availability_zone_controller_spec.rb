describe AvailabilityZoneController do
  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @zone = FactoryGirl.create(:availability_zone)
      @user = FactoryGirl.create(:user_admin)
      login_as @user
    end

    subject do
      get :show, :id => @zone.id
    end

    context "respond_with" do
      it { is_expected.to have_http_status 200 }

      it { is_expected.not_to have_http_status 500 }
    end

    context "render listnav partial" do
      render_views

      it { is_expected.to render_template(:partial => "layouts/listnav/_availability_zone") }
    end
  end
end
