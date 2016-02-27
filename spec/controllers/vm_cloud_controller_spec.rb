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
    before do
      ApplicationController.handle_exceptions = true
    end

    context 'for allowed actions' do
      ApplicationController::Explorer::X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
        prefixes = ["image", "instance"]
        prefixes.each do |prefix|
          actual_action = "#{prefix}_#{action_name}"
          actual_method = [:s1, :s2].include?(method) ? actual_action : method.to_s

          it "calls the appropriate method: '#{actual_method}' for action '#{actual_action}'" do
            expect(controller).to receive(actual_method)
            get :x_button, :params => { :id => nil, :pressed => actual_action }
          end
        end
      end
    end

    context 'for an unknown action' do
      render_views

      it 'exception is raised for unknown action' do
        EvmSpecHelper.create_guid_miq_server_zone
        get :x_button, :params => { :id => nil, :pressed => 'random_dude', :format => :html }
        expect(response).to render_template('layouts/exception')
        expect(response.body).to include('Action not implemented')
      end
    end
  end

  context "with rendered views" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      get :explorer
    end

    render_views

    it 'can render the explorer' do
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end

    context "skip or drop breadcrumb" do
      subject { controller.instance_variable_get(:@breadcrumbs) }

      it 'skips dropping a breadcrumb when a button action is executed' do
        ApplicationController.handle_exceptions = true

        post :x_button, :params => { :id => nil, :pressed => 'instance_ownership' }
        expect(subject).to eq([{:name => "Instances", :url => "/vm_cloud/explorer"}])
      end

      it 'drops a breadcrumb when an action allowing breadcrumbs is executed' do
        post :accordion_select, :params => { :id => "images_filter" }
        expect(subject).to eq([{:name => "Images", :url => "/vm_cloud/explorer"}])
      end
    end
  end
end
