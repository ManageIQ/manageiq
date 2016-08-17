include CompressedIds

describe CloudSubnetController do
  render_views
  before :each do
    stub_user(:features => :all)
    setup_zone
  end

  %w(openstack amazon azure google).each do |t|
    context "for #{t}" do
      before :each do
        @cloud_subnet = FactoryGirl.create("cloud_subnet_#{t}".to_sym, :name => "Cloud Subnet")
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
          get :show, :params => {:id => @cloud_subnet.id}
          expect(response.status).to eq(200)
          expect(response.body).to_not be_empty
          expect(assigns(:breadcrumbs)).to eq([{:name => "cloud_subnets",
                                                :url  => "/cloud_subnet/show_list?page=&refresh=y"},
                                               {:name => "Cloud Subnet (Summary)",
                                                :url  => "/cloud_subnet/show/#{@cloud_subnet.id}"}])

          is_expected.to render_template(:partial => "layouts/listnav/_cloud_subnet")
        end

        it "shows associated cloud_subnets" do
          child_subnet = FactoryGirl.create(
            "cloud_subnet_#{t}".to_sym, :name => "Child Cloud Subnet", :parent_cloud_subnet => @cloud_subnet)

          controller.instance_variable_set(:@breadcrumbs, [])
          get :show, :params => {:id => @cloud_subnet.id, :display => 'cloud_subnets'}
          expect(response.status).to eq(200)
          expect(response).to render_template('cloud_subnet/show')
          expect(response).to render_template('layouts/listnav/_cloud_subnet')
          expect(assigns(:breadcrumbs)).to eq([{:name => "#{@cloud_subnet.name} (All Cloud Subnets)",
                                                :url  => "/cloud_subnet/show/#{@cloud_subnet.id}?display=cloud_subnets"}])
          child_subnet_row = "miqRowClick(&#39;#{child_subnet.compressed_id}&#39;, &#39;/cloud_subnet/show/&#39;"
          expect(response.body).to include(child_subnet_row)

          # display needs to be saved to session for GTL pagination and such
          expect(session[:cloud_subnet_display]).to eq('cloud_subnets')
        end
      end

      describe "#test_toolbars" do
        it 'edit cloud subnet tags' do
          post :button, :params => {:miq_grid_checks => to_cid(@cloud_subnet.id), :pressed => "cloud_subnet_tag"}
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
