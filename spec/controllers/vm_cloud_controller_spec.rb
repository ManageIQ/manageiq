require "spec_helper"

describe VmCloudController do
  before(:each) do
    set_user_privileges
  end

  # All of the x_button is a suplement for Rails routes that is written in
  # controller.
  #
  # You pass in query param 'pressed' and from that the actual route is
  # determined.
  #
  # So we need a test for each possible value of 'presses' until all this is
  # converted into proper routes and test is changed to test the new routes.
  describe 'x_button' do
    describe 'corresponding methods are called for allowed actions' do
      ApplicationController::Explorer::X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
        prefixes = ["image", "instance"]
        prefixes.each do |prefix|
          actual_action = "#{prefix}_" + action_name
          actual_method = if method == :s1 || method == :s2
              "#{prefix}_" + action_name
            else
              method.to_s
            end
          it "calls the appropriate method: '#{actual_method}' for action '#{actual_action}'" do
            controller.stub(:x_button_response)
            controller.should_receive(actual_method)
            get :x_button, :id => FactoryGirl.create(:template_redhat), :pressed => actual_action
          end
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :id => FactoryGirl.create(:template_redhat), :pressed => 'random_dude', :format => :html
      expect { response }.to render_template('layouts/exception')
    end
  end

  render_views

  it 'can render the explorer' do
    session[:settings] = {:views => {}, :perpage => {:list => 10}}

    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone
    expect(MiqServer.my_server).to be
    get :explorer
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end

  context "skip or drop breadcrumb" do
    before do
      session[:settings] = {:views => {}, :perpage => {:list => 10}}
      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.create_guid_miq_server_zone
      @vmcloud = VmCloud.create(:name     => "test_vmcloud",
                                :location => "test_vmcloud_location",
                                :vendor   => "openstack")
      get :explorer
      request.env['HTTP_REFERER'] = request.fullpath
    end

    it 'skips dropping a breadcrumb when a button action is executed' do
      post :x_button, :id => @vmcloud.id, :pressed => 'instance_ownership'
      breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
      expect(breadcrumbs.size).to eq(1)
      expect(breadcrumbs).to include(:name => "Instances", :url => "/vm_cloud/explorer")
    end

    it 'drops a breadcrumb when an action allowing breadcrumbs is executed' do
      post :accordion_select, :id => "images_filter"
      breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
      expect(breadcrumbs.size).to eq(1)
      expect(breadcrumbs).to include(:name => "Images", :url => "/vm_cloud/explorer")
    end
  end
end
