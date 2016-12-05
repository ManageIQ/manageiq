require Rails.root.join('spec/shared/controllers/shared_examples_for_cloud_network_controller')

describe CloudNetworkController do
  include_examples :shared_examples_for_cloud_network_controller, %w(openstack azure google)

  context "#button" do
    before(:each) do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      ApplicationController.handle_exceptions = true
    end

    it "when Edit Tag is pressed" do
      skip "No ready yet"
      expect(controller).to receive(:tag)
      post :button, :params => { :pressed => "edit_tag", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end
  end

  context "#tags_edit" do
    let!(:user) { stub_user(:features => :all) }
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ct = FactoryGirl.create(:cloud_network, :name => "cloud-network-01")
      allow(@ct).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@ct).and_return([@tag1, @tag2])
      session[:tag_db] = "CloudNetwork"
      edit = {
        :key        => "CloudNetwork_edit_tags__#{@ct.id}",
        :tagging    => "CloudNetwork",
        :object_ids => [@ct.id],
        :current    => {:assignments => []},
        :new        => {:assignments => [@tag1.id, @tag2.id]}
      }
      session[:edit] = edit
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "builds tagging screen" do
      post :button, :params => { :pressed => "cloud_network_tag", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array)).to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "cloud_network/show/#{@ct.id}"}, 'placeholder']
      post :tagging_edit, :params => { :button => "cancel", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array).first[:message]).to include("was cancelled by the user")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "cloud_network/show/#{@ct.id}"}, 'placeholder']
      post :tagging_edit, :params => { :button => "save", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end
  end

  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @network = FactoryGirl.create(:cloud_network)
      login_as FactoryGirl.create(:user)
    end

    subject do
      get :show, :params => {:id => @network.id}
    end

    context "render listnav partial" do
      render_views
      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_cloud_network")
      end
    end
  end

  describe "#create" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack).network_manager
      @network = FactoryGirl.create(:cloud_network_openstack)
    end

    it "builds create screen" do
      post :button, :params => { :pressed => "cloud_network_new", :format => :js }
      expect(assigns(:flash_array)).to be_nil
    end

    it "creates a cloud network" do
      allow(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork)
        .to receive(:raw_create_network).and_return(@network)
      post :create, :params => { :button => "add", :format => :js,
        :name => "test", :tenant_id => 'id', :ems_id => @ems.id }
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(assigns(:flash_array).first[:message]).to include("Creating Cloud Network")
      expect(assigns(:edit)).to be_nil
    end
  end

  describe "#edit" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @network = FactoryGirl.create(:cloud_network_openstack)
    end

    it "builds edit screen" do
      post :button, :params => { :pressed => "cloud_network_edit", :format => :js, :id => @network.id }
      expect(assigns(:flash_array)).to be_nil
    end

    it "updates itself" do
      skip "Issue with flash message not matching"
      allow_any_instance_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork)
        .to receive(:raw_update_network)
      session[:breadcrumbs] = [{:url => "cloud_network/show/#{@network.id}"}, 'placeholder']
      post :update, :params => { :button => "save", :format => :js, :id => @network.id }
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(assigns(:flash_array).first[:message]).to include("Updating Cloud Network")
      expect(assigns(:edit)).to be_nil
    end
  end

  describe "#delete" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @network = FactoryGirl.create(:cloud_network_openstack)
      session[:cloud_network_lastaction] = 'show'
    end

    it "deletes itself" do
      allow_any_instance_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork)
        .to receive(:raw_delete_network)
      post :button, :params => { :id => @network.id, :pressed => "cloud_network_delete", :format => :js }
      # request to delete one network should always return one flash message with info about success/failure that cannot be foreseen
      expect(controller.instance_variable_get(:@flash_array).size).to eq(1)
    end
  end
end
