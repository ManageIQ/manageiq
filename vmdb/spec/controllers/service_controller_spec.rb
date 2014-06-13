require "spec_helper"

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
        :trees => {
          :svcs_tree => {:active_node => "#{svc.id}"}
        },
        :active_tree => :svcs_tree
      )

      controller.stub(:replace_right_cell)

      # Now delete the Service
      controller.instance_variable_set(:@_params, {:id => svc.id})
      controller.send(:service_delete)

      # Check for Service Description to be part of flash message displayed
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should include("Service \"GemFire\": Delete successful")

      controller.send(:flash_errors?).should_not be_true
    end
  end

  describe 'x_button' do
    describe 'corresponding methods are called for allowed actions' do
      ServiceController::SERVICE_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
        it "calls the appropriate method: '#{method}' for action '#{action_name}'" do
          controller.should_receive(method)
          get :x_button, :pressed => action_name
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :pressed => 'random_dude', :format => :html
      expect { response }.to render_template('layouts/exception')
    end
  end
end
