require "spec_helper"

describe VmOrTemplateController do
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
        actual_action = 'vm_' + action_name
        actual_method = if method == :s1 || method == :s2
                          'vm_' + action_name
                        else
                          method.to_s
                        end
        it "calls the appropriate method: '#{actual_method}' for action '#{actual_action}'" do
          controller.stub(:x_button_response)
          controller.should_receive(actual_method)
          get :x_button, :id => FactoryGirl.create(:vm_redhat), :pressed => actual_action
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :pressed => 'random_dude', :format => :html
      expect { response }.to render_template('layouts/exception')
    end

    context "x_button method check" do
      let(:vm_infra) { FactoryGirl.create(:vm_vmware) }
      before(:each) do
        controller.instance_variable_set(:@_orig_action, "x_history")
      end

      it "should set correct VM for right-sizing when on vm list view" do
        controller.should_receive(:replace_right_cell)
        post :x_button, :pressed => "vm_right_size", :id => vm_infra.id, :check_10r839 => '1'
        controller.send(:flash_errors?).should_not be_true
        assigns(:record).id == vm_infra.id
      end

      it "should set correct VM for right-sizing when from vm summary screen" do
        controller.should_receive(:replace_right_cell)
        post :x_button, :pressed => "vm_right_size", :id => vm_infra.id
        controller.send(:flash_errors?).should_not be_true
        assigns(:record).id == vm_infra.id
      end
    end
  end

  render_views

  context '#explorer' do
    before(:each) do
      session[:settings] = {:views => {}, :perpage => {:list => 10}}

      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.create_guid_miq_server_zone
    end

    it 'can render the explorer' do
      expect(MiqServer.my_server).to be
      get :explorer
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end

    it 'shows a template in the templates list' do
      FactoryGirl.create(:template_vmware, :name => 'dempsey')
      session[:sb] = {:active_accord => :templates_images_filter}
      seed_session_trees('vm_or_template', :templates_images_filter_tree, 'root')

      get :explorer
      expect(response.body).to match(%r{<cell>dempsey<\\/cell>})
    end

    it 'show a vm in the vms instances list' do
      FactoryGirl.create(:vm_vmware, :name => 'makepeace')
      get :explorer
      expect(response.body).to match(%r{<cell>makepeace<\\/cell>})
    end
  end

  context "#tree_select" do
    before :each do
      User.stub(:find_by_userid).and_return(User.current_user)
      EvmSpecHelper.create_guid_miq_server_zone
    end

    [
      ['Vms & Instances', 'vms_instances_filter_tree'],
      ['Templates & Image', 'templates_images_filter_tree'],
    ].each do |elements, tree|
      it "renders list of #{elements} for #{tree} root node" do
        FactoryGirl.create(:vm_vmware)
        FactoryGirl.create(:template_vmware)

        session[:settings] = {}
        seed_session_trees('vm_or_template', tree.to_sym)

        post :tree_select, :id => 'root', :format => :js

        response.should render_template('layouts/gtl/_list')
        expect(response.status).to eq(200)
      end
    end
  end

  context "skip or drop breadcrumb" do
    before do
      session[:settings] = {:views => {}, :perpage => {:list => 10}}
      session[:userid] = User.current_user.userid
      session[:eligible_groups] = []
      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.create_guid_miq_server_zone
      @vm_or_template = VmOrTemplate.create(:name     => "test_vm_or_template",
                                            :location => "test_vm_or_template_location",
                                            :vendor   => "vmware")
      get :explorer
      request.env['HTTP_REFERER'] = request.fullpath
    end

    it 'skips dropping a breadcrumb when a button action is executed' do
      post :x_button, :id => @vm_or_template.id, :pressed => 'miq_template_ownership'
      breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
      expect(breadcrumbs.size).to eq(1)
      expect(breadcrumbs).to include(:name => "VMs and Instances", :url => "/vm_or_template/explorer")
    end

    it 'drops a breadcrumb when an action allowing breadcrumbs is executed' do
      post :accordion_select, :id => "templates_images_filter"
      breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
      expect(breadcrumbs.size).to eq(1)
      expect(breadcrumbs).to include(:name => "VM Templates and Images", :url => "/vm_or_template/explorer")
    end
  end
end
