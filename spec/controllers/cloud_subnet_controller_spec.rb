require Rails.root.join('spec/shared/controllers/shared_examples_for_cloud_subnet_controller')

describe CloudSubnetController do
  include_examples :shared_examples_for_cloud_subnet_controller, %w(openstack azure google)

  context "#button" do
    before(:each) do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone

      ApplicationController.handle_exceptions = true
    end

    it "when Edit Tag is pressed" do
      # TODO: Fix
      skip "Not ready yet"
      expect(controller).to receive(:tag)
      post :button, :params => { :pressed => "edit_tag", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end
  end

  context "#tags_edit" do
    let!(:user) { stub_user(:features => :all) }
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ct = FactoryGirl.create(:cloud_subnet, :name => "cloud-subnet-01")
      allow(@ct).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@ct).and_return([@tag1, @tag2])
      session[:tag_db] = "CloudSubnet"
      edit = {
        :key        => "CloudSubnet_edit_tags__#{@ct.id}",
        :tagging    => "CloudSubnet",
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
      post :button, :params => { :pressed => "cloud_subnet_tag", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array)).to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "cloud_subnet/show/#{@ct.id}"}, 'placeholder']
      post :tagging_edit, :params => { :button => "cancel", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array).first[:message]).to include("was cancelled by the user")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "cloud_subnet/show/#{@ct.id}"}, 'placeholder']
      post :tagging_edit, :params => { :button => "save", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end
  end

  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @subnet = FactoryGirl.create(:cloud_subnet)
      login_as FactoryGirl.create(:user)
    end

    subject do
      get :show, :params => {:id => @subnet.id}
    end

    context "render listnav partial" do
      render_views
      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_cloud_subnet")
      end
    end
  end

  describe "#create" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack).network_manager
      @subnet = FactoryGirl.create(:cloud_subnet_openstack)
    end

    it "builds create screen" do
      post :button, :params => { :pressed => "cloud_subnet_new", :format => :js }
      expect(assigns(:flash_array)).to be_nil
    end

    it "creates a cloud subnet" do
      allow(ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet)
        .to receive(:raw_create_subnet).and_return(@subnet)
      post :create, :params => { :button => "add", :format => :js,
        :name => "test", :network_id => "id", :cidr => "172.16.1.0/24",
        :gateway => "172.16.1.0", :tenant_id => 'id', :ems_id => @ems.id }
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(assigns(:flash_array).first[:message]).to include("Creating Cloud Subnet")
      expect(assigns(:edit)).to be_nil
    end
  end

  describe "#edit" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @subnet = FactoryGirl.create(:cloud_subnet_openstack)
    end

    it "builds edit screen" do
      post :button, :params => { :pressed => "cloud_subnet_edit", :format => :js, :id => @subnet.id }
      expect(assigns(:flash_array)).to be_nil
    end

    it "updates itself" do
      allow_any_instance_of(ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet)
        .to receive(:raw_update_subnet)
      session[:breadcrumbs] = [{:url => "cloud_subnet/show/#{@subnet.id}"}, 'placeholder']
      post :update, :params => { :button => "save", :format => :js, :id => @subnet.id }
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(assigns(:flash_array).first[:message]).to include("Updating Subnet")
      expect(assigns(:edit)).to be_nil
    end
  end

  describe "#delete" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack).network_manager
      @subnet = FactoryGirl.create(:cloud_subnet_openstack, :ext_management_system => @ems)
      session[:cloud_subnet_lastaction] = 'show'
    end

    it "deletes itself" do
      allow_any_instance_of(ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet)
        .to receive(:raw_delete_subnet)
      post :button, :params => { :id => @subnet.id, :pressed => "cloud_subnet_delete", :format => :js }
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(assigns(:flash_array).first[:message]).to include("Delete initiated for 1 Cloud Subnet")
    end
  end
end
