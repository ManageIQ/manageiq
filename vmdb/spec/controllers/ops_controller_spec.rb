require "spec_helper"

describe OpsController do
  before(:each) do
    set_user_privileges
  end

  describe 'x_button' do
    describe 'corresponding methods are called for allowed actions' do
      OpsController::OPS_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
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
