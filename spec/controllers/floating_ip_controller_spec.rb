include CompressedIds

describe FloatingIpController do
  render_views
  before :each do
    set_user_privileges
    setup_zone
  end

  %w(openstack).each do |t|
    context "for #{t}" do
      before :each do
        @floating_ip = FactoryGirl.create("floating_ip_#{t}".to_sym, :address => "192.0.2.1")
      end

      describe "#show_list" do
        it "renders index" do
          get :index
          expect(response.status).to eq(302)
          expect(response).to redirect_to(:action => 'show_list')
        end

        it "renders show_list" do
          # TODO(lsmola) figure out why I have to mock pdf available here, but not in other Manager's lists
          allow(PdfGenerator).to receive_messages(:available? => false)
          session[:settings] = {:default_search => 'foo',
                                :views          => {},
                                :perpage        => {:list => 10}}
          get :show_list
          expect(response.status).to eq(200)
          expect(response.body).to_not be_empty
        end
      end

      describe "#show" do
        it "renders show screen" do
          get :show, :params => {:id => @floating_ip.id}
          expect(response.status).to eq(200)
          expect(response.body).to_not be_empty
          expect(assigns(:breadcrumbs)).to eq([{:name => "floating_ips",
                                                :url  => "/floating_ip/show_list?page=&refresh=y"},
                                               {:name => "192.0.2.1 (Summary)",
                                                :url  => "/floating_ip/show/#{@floating_ip.id}"}])

          is_expected.to render_template(:partial => "layouts/listnav/_floating_ip")
        end
      end

      describe "#test_toolbars" do
        it 'edit floating ip tags' do
          post :button, :params => {:miq_grid_checks => to_cid(@floating_ip.id), :pressed => "floating_ip_tag"}
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
