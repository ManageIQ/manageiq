require_relative 'shared_network_manager_context'

shared_examples :shared_examples_for_cloud_network_controller do |providers|
  include CompressedIds

  render_views
  before :each do
    stub_user(:features => :all)
    setup_zone
  end

  providers.each do |t|
    context "for #{t}" do
      include_context :shared_network_manager_context, t

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
          expect(assigns(:breadcrumbs)).to eq([{:name => "Cloud Networks",
                                                :url  => "/cloud_network/show_list?page=&refresh=y"},
                                               {:name => "Cloud Network (Summary)",
                                                :url  => "/cloud_network/show/#{@cloud_network.id}"}])

          is_expected.to render_template(:partial => "layouts/listnav/_cloud_network")
        end

        it "show associated cloud_subnets" do
          assert_nested_list(@cloud_network, [@cloud_subnet], 'cloud_subnets', 'All Cloud Subnets')
        end

        it "show associated network routers" do
          assert_nested_list(@cloud_network, [@network_router], 'network_routers', 'All Network Routers')
        end

        it "show associated instances" do
          assert_nested_list(@cloud_network, [@vm], 'instances', 'All Instances', :child_path => 'vm_cloud')
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
