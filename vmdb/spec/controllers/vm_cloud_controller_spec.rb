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
end
