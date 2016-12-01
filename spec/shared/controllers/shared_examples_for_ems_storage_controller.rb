require_relative 'shared_storage_manager_context'

shared_examples :shared_examples_for_ems_storage_controller do |providers|
  include CompressedIds
  render_views
  before :each do
    stub_user(:features => :all)
    setup_zone
  end

  providers.each do |t|
    context "for #{t}" do
      include_context :shared_storage_manager_context, t

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
          get :show, :params => {:id => @ems.id}
          expect(response.status).to eq(200)
          expect(response.body).to_not be_empty
          expect(assigns(:breadcrumbs)).to eq([{:name => "Storage Managers",
                                                :url  => "/ems_storage/show_list?page=&refresh=y"},
                                               {:name => "Test Cloud Manager Cinder Manager (Summary)",
                                                :url  => "/ems_storage/show/#{@ems.id}"}])

          is_expected.to render_template(:partial => "layouts/listnav/_ems_storage")
        end
      end

      describe "#test_toolbars" do
        it "refresh relationships and power states" do
          post :button, :params => {:id => @ems.id, :pressed => "ems_storage_refresh"}
          expect(response.status).to eq(200)
        end

        it 'edit network provider tags' do
          post :button, :params => {:miq_grid_checks => to_cid(@ems.id), :pressed => "ems_storage_tag"}
          expect(response.status).to eq(200)
        end

        it 'manage storage provider policies' do
          allow(controller).to receive(:protect_build_tree).and_return(nil)
          controller.instance_variable_set(:@protect_tree, OpenStruct.new(:name => "name"))

          post :button, :params => {:miq_grid_checks => to_cid(@ems.id), :pressed => "ems_storage_protect"}
          expect(response.status).to eq(200)

          get :protect
          expect(response.status).to eq(200)
          expect(response).to render_template('shared/views/protect')
        end
      end
    end
  end
end
