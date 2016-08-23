require Rails.root.join('spec/support/controller_spec_helper')

shared_examples :cloud_network_controller_spec do |providers|
  include CompressedIds

  render_views
  before :each do
    stub_user(:features => :all)
    setup_zone
  end

  providers.each do |t|
    context "for #{t}" do
      before :each do
        @provider       = FactoryGirl.create("ems_#{t}".to_sym,
                                             :name => "Cloud Manager")
        @security_group = FactoryGirl.create("security_group_#{t}".to_sym,
                                             :ext_management_system => @provider.network_manager,
                                             :name                  => 'Security Group')
        @vm             = FactoryGirl.create("vm_#{t}".to_sym,
                                             :name => "Instance")
        if t == 'openstack'
          @cloud_network        = FactoryGirl.create("cloud_network_private_#{t}".to_sym,
                                                     :name => "Cloud Network")
          @cloud_network_public = FactoryGirl.create("cloud_network_public_#{t}".to_sym,
                                                     :name => "Cloud Network Public")
        else
          @cloud_network        = FactoryGirl.create("cloud_network_#{t}".to_sym,
                                                     :name => "Cloud Network")
          @cloud_network_public = nil
        end

        @network_router = FactoryGirl.create("network_router_#{t}".to_sym,
                                             :cloud_network => @cloud_network_public,
                                             :name          => "Network Router")

        @cloud_subnet = FactoryGirl.create("cloud_subnet_#{t}".to_sym,
                                           :network_router        => @network_router,
                                           :cloud_network         => @cloud_network,
                                           :ext_management_system => @provider.network_manager,
                                           :name                  => "Cloud Subnet")

        @floating_ip = FactoryGirl.create("floating_ip_#{t}".to_sym,
                                          :ext_management_system => @provider.network_manager)
        @vm.network_ports << @network_port = FactoryGirl.create("network_port_#{t}".to_sym,
                                                                :name            => "eth0",
                                                                :device          => @vm,
                                                                :security_groups => [@security_group],
                                                                :floating_ip     => @floating_ip)
        FactoryGirl.create(:cloud_subnet_network_port, :cloud_subnet => @cloud_subnet, :network_port => @network_port)
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
