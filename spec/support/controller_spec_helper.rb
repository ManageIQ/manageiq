module ControllerSpecHelper
  def assigns(key = nil)
    if key.nil?
      @controller.view_assigns.symbolize_keys
    else
      @controller.view_assigns[key.to_s]
    end
  end

  def set_user_privileges(user = FactoryGirl.create(:user))
    allow(User).to receive(:server_timezone).and_return("UTC")
    described_class.any_instance.stub(:set_user_time_zone)

    # TODO: remove these stubs
    controller.stub(:check_privileges).and_return(true)
    login_as user
    User.any_instance.stub(:role_allows?).and_return(true)
  end

  shared_context "valid session" do
    let(:privilege_checker_service) { auto_loaded_instance_double("PrivilegeCheckerService", :valid_session?  => true) }
    let(:request_referer_service)   { auto_loaded_instance_double("RequestRefererService",   :allowed_access? => true) }

    before do
      controller.stub(:set_user_time_zone)
      PrivilegeCheckerService.stub(:new).and_return(privilege_checker_service)
      RequestRefererService.stub(:new).and_return(request_referer_service)
    end
  end

  def seed_session_trees(a_controller, active_tree, node = nil)
    session[:sandboxes] = {
      a_controller => {
        :trees       => {
          active_tree => {}
        },
        :active_tree => active_tree
      }
    }
    session[:sandboxes][a_controller][:trees][active_tree][:active_node] = node unless node.nil?
  end
end
