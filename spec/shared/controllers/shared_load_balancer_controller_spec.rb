include CompressedIds

shared_examples :load_balancer_controller_spec do |providers|
  render_views
  before :each do
    stub_user(:features => :all)
    setup_zone
  end

  providers.each do |t|
    context "for #{t}" do
      before :each do
        @load_balancer             = FactoryGirl.create("load_balancer_#{t}".to_sym, :name => "Load Balancer")
        _load_balancer_2           = FactoryGirl.create("load_balancer_#{t}".to_sym)
        vm                         = FactoryGirl.create("vm_#{t}".to_sym)
        load_balancer_pool         = FactoryGirl.create("load_balancer_pool_#{t}".to_sym)
        load_balancer_listener     = FactoryGirl.create("load_balancer_listener_#{t}".to_sym,
                                                        :load_balancer => @load_balancer)
        load_balancer_pool_member  = FactoryGirl.create("load_balancer_pool_member_#{t}".to_sym,
                                                        :vm => vm)
        load_balancer_health_check = FactoryGirl.create("load_balancer_health_check_#{t}".to_sym)

        FactoryGirl.create("load_balancer_listener_pool".to_sym,
                           :load_balancer_pool     => load_balancer_pool,
                           :load_balancer_listener => load_balancer_listener)
        FactoryGirl.create("load_balancer_pool_member_pool".to_sym,
                           :load_balancer_pool        => load_balancer_pool,
                           :load_balancer_pool_member => load_balancer_pool_member)
        FactoryGirl.create("load_balancer_health_check_member".to_sym,
                           :load_balancer_health_check => load_balancer_health_check,
                           :load_balancer_pool_member  => load_balancer_pool_member)
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
          get :show, :params => {:id => @load_balancer.id}
          expect(response.status).to eq(200)
          expect(response.body).to_not be_empty
          expect(assigns(:breadcrumbs)).to eq([{:name => "load_balancers",
                                                :url  => "/load_balancer/show_list?page=&refresh=y"},
                                               {:name => "Load Balancer (Summary)",
                                                :url  => "/load_balancer/show/#{@load_balancer.id}"}])

          is_expected.to render_template(:partial => "layouts/listnav/_load_balancer")
        end
      end

      describe "#test_toolbars" do
        it 'edit cloud subnet tags' do
          post :button, :params => {:miq_grid_checks => to_cid(@load_balancer.id), :pressed => "load_balancer_tag"}
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
