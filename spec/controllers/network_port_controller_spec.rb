include CompressedIds

describe NetworkPortController do
  render_views
  before :each do
    set_user_privileges
    setup_zone
  end

  %w(openstack amazon).each do |t|
    context "for #{t}" do
      before :each do
        @network_port = FactoryGirl.create("network_port_#{t}".to_sym, :name => "Network Port")
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
          get :show, :params => {:id => @network_port.id}
          expect(response.status).to eq(200)
          expect(response.body).to_not be_empty
          expect(assigns(:breadcrumbs)).to eq([{:name => "network_ports",
                                                :url  => "/network_port/show_list?page=&refresh=y"},
                                               {:name => "Network Port (Summary)",
                                                :url  => "/network_port/show/#{@network_port.id}"}])

          is_expected.to render_template(:partial => "layouts/listnav/_network_port")
        end
      end

      describe "#test_toolbars" do
        it 'edit Network Port tags' do
          post :button, :params => {:miq_grid_checks => to_cid(@network_port.id), :pressed => "network_port_tag"}
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
