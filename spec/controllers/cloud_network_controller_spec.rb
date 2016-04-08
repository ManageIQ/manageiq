include CompressedIds

describe CloudNetworkController do
  render_views
  before :each do
    set_user_privileges
    setup_zone
  end

  %w(openstack amazon).each do |t|
    context "for #{t}" do
      before :each do
        @cloud_network = FactoryGirl.create("cloud_network_#{t}".to_sym, :name => "Cloud Network")
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
          get :show, :params => {:id => @cloud_network.id}
          expect(response.status).to eq(200)
          expect(response.body).to_not be_empty
          expect(assigns(:breadcrumbs)).to eq([{:name => "cloud_networks",
                                                :url  => "/cloud_network/show_list?page=&refresh=y"},
                                               {:name => "Cloud Network (Summary)",
                                                :url  => "/cloud_network/show/#{@cloud_network.id}"}])

          is_expected.to render_template(:partial => "layouts/listnav/_cloud_network")
        end
      end

      describe "#test_toolbars" do
        it 'edit Cloud Network tags' do
          post :button, :params => {:miq_grid_checks => to_cid(@cloud_network.id), :pressed => "cloud_network_tag"}
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
