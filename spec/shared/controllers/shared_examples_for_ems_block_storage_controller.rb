require_relative 'shared_storage_manager_context'

shared_examples :shared_examples_for_ems_block_storage_controller do |providers|
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
    end
  end
end
