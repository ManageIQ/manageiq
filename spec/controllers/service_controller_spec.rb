describe ServiceController do
  before(:each) do
    set_user_privileges
  end

  context "#service_delete" do
    it "display flash message with description of deleted Service" do
      st  = FactoryGirl.create(:service_template)
      svc = FactoryGirl.create(:service, :service_template => st, :name => "GemFire", :description => "VMware vFabric GEMFIRE")

      controller.instance_variable_set(:@record, svc)
      controller.instance_variable_set(:@sb,
                                       :trees       => {
                                         :svcs_tree => {:active_node => "#{svc.id}"}
                                       },
                                       :active_tree => :svcs_tree
                                      )

      allow(controller).to receive(:replace_right_cell)

      # Now delete the Service
      controller.instance_variable_set(:@_params, :id => svc.id)
      controller.send(:service_delete)

      # Check for Service Description to be part of flash message displayed
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include("Service \"GemFire\": Delete successful")

      expect(controller.send(:flash_errors?)).not_to be_truthy
    end
  end

  describe 'x_button' do
    before do
      ApplicationController.handle_exceptions = true
    end

    describe 'corresponding methods are called for allowed actions' do
      ServiceController::SERVICE_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
        it "calls the appropriate method: '#{method}' for action '#{action_name}'" do
          expect(controller).to receive(method)
          get :x_button, :params => { :pressed => action_name }
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :params => { :pressed => 'random_dude', :format => :html }
      expect(response).to render_template('layouts/exception')
    end
  end

  context "#service_delete" do
    it "replaces right cell after service is deleted" do
      service = FactoryGirl.create(:service)
      allow(controller).to receive(:x_build_dynatree)
      controller.instance_variable_set(:@settings, {})
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@_params, :id => service.id)
      expect(controller).to receive(:render)
      expect(response.status).to eq(200)
      controller.send(:service_delete)

      flash_message = assigns(:flash_array).first
      expect(flash_message[:message]).to include("Delete successful")
      expect(flash_message[:level]).to be(:success)
    end
  end
end
