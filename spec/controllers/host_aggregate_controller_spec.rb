describe HostAggregateController do
  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @aggregate = FactoryGirl.create(:host_aggregate)
      login_as FactoryGirl.create(:user_admin)
    end

    subject do
      get :show, :params => {:id => @aggregate.id}
    end

    context "render listnav partial" do
      render_views

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_host_aggregate")
      end
    end
  end
end
