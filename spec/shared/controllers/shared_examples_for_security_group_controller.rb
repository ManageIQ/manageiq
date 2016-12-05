require_relative 'shared_network_manager_context'

shared_examples :shared_examples_for_security_group_controller do |providers|
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
          get :show, :params => {:id => @security_group.id}
          expect(response.status).to eq(200)
          expect(response.body).to_not be_empty
          expect(assigns(:breadcrumbs)).to eq([{:name => "Security Groups",
                                                :url  => "/security_group/show_list?page=&refresh=y"},
                                               {:name => "Security Group (Summary)",
                                                :url  => "/security_group/show/#{@security_group.id}"}])

          is_expected.to render_template(:partial => "layouts/listnav/_security_group")
        end

        it "show associated instances" do
          assert_nested_list(@security_group, [@vm], 'instances', 'All Instances', :child_path => 'vm_cloud')
        end

        it "show associated network ports" do
          assert_nested_list(@security_group, [@network_port], 'network_ports', 'All Network Ports')
        end
      end

      describe "#test_toolbars" do
        it 'edit security group tags' do
          post :button, :params => {:miq_grid_checks => to_cid(@security_group.id), :pressed => "security_group_tag"}
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
