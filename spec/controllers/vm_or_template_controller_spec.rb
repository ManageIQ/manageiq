describe VmOrTemplateController do
  let(:template_vmware) { FactoryGirl.create(:template_vmware, :name => 'template_vmware Name') }
  let(:vm_vmware)       { FactoryGirl.create(:vm_vmware, :name => "vm_vmware Name") }
  before { set_user_privileges }

  # All of the x_button is a suplement for Rails routes that is written in
  # controller.
  #
  # You pass in query param 'pressed' and from that the actual route is
  # determined.
  #
  # So we need a test for each possible value of 'presses' until all this is
  # converted into proper routes and test is changed to test the new routes.
  describe 'x_button' do
    before do
      ApplicationController.handle_exceptions = true
    end

    describe 'corresponding methods are called for allowed actions' do
      ApplicationController::Explorer::X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
        actual_action = 'vm_' + action_name
        actual_method = [:s1, :s2].include?(method) ? actual_action : method.to_s

        it "calls the appropriate method: '#{actual_method}' for action '#{actual_action}'" do
          expect(controller).to receive(actual_method)
          get :x_button, :params => { :id => nil, :pressed => actual_action }
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :params => { :pressed => 'random_dude', :format => :html }
      expect(response).to render_template('layouts/exception')
    end

    context "x_button method check" do
      before { controller.instance_variable_set(:@_orig_action, "x_history") }

      it "should set correct VM for right-sizing when on vm list view" do
        expect(controller).to receive(:replace_right_cell)
        post :x_button, :params => { :pressed => "vm_right_size", :id => vm_vmware.id, :check_10r839 => '1' }
        expect(controller.send(:flash_errors?)).not_to be_truthy
        assigns(:record).id == vm_vmware.id
      end

      it "should set correct VM for right-sizing when from vm summary screen" do
        expect(controller).to receive(:replace_right_cell)
        post :x_button, :params => { :pressed => "vm_right_size", :id => vm_vmware.id }
        expect(controller.send(:flash_errors?)).not_to be_truthy
        assigns(:record).id == vm_vmware.id
      end
    end
  end

  context "skip or drop breadcrumb" do
    before do
      session[:settings] = {:views => {}, :perpage => {:list => 10}}
      EvmSpecHelper.create_guid_miq_server_zone
      get :explorer
    end

    it 'skips dropping a breadcrumb when a button action is executed' do
      ApplicationController.handle_exceptions = true

      post :x_button, :params => { :id => nil, :pressed => 'miq_template_ownership' }
      breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
      expect(breadcrumbs).to eq([{:name => "VMs and Instances", :url => "/vm_or_template/explorer"}])
    end

    it 'drops a breadcrumb when an action allowing breadcrumbs is executed' do
      post :accordion_select, :params => { :id => "templates_images_filter" }
      breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
      expect(breadcrumbs).to eq([{:name => "VM Templates and Images", :url => "/vm_or_template/explorer"}])
    end
  end

  context 'render_views' do
    render_views

    context '#explorer' do
      before do
        session[:settings] = {:views => {}, :perpage => {:list => 10}}
        EvmSpecHelper.create_guid_miq_server_zone
      end

      it 'can render the explorer' do
        get :explorer
        expect(response.status).to eq(200)
        expect(response.body).to_not be_empty
      end

      it 'shows a template in the templates list' do
        template_vmware
        session[:sb] = {:active_accord => :templates_images_filter}
        seed_session_trees('vm_or_template', :templates_images_filter_tree, 'root')

        get :explorer
        expect(response.body).to match(%r({"text":\s*"template_vmware Name"}))
      end

      it 'show a vm in the vms instances list' do
        vm_vmware
        get :explorer
        expect(response.body).to match(%r({"text":\s*"vm_vmware Name"}))
      end
    end

    context "#tree_select" do
      before do
        template_vmware
        vm_vmware
      end

      [
        ['Vms & Instances', 'vms_instances_filter_tree'],
        ['Templates & Image', 'templates_images_filter_tree'],
      ].each do |elements, tree|
        it "renders list of #{elements} for #{tree} root node" do
          session[:settings] = {}
          seed_session_trees('vm_or_template', tree.to_sym)

          post :tree_select, :params => { :id => 'root', :format => :js }

          expect(response).to render_template('layouts/gtl/_list')
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
