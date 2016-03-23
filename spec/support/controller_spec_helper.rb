module ControllerSpecHelper
  def assigns(key = nil)
    if key.nil?
      @controller.view_assigns.symbolize_keys
    else
      @controller.view_assigns[key.to_s]
    end
  end

  def set_user_privileges(user = FactoryGirl.create(:user_with_group))
    allow(User).to receive(:server_timezone).and_return("UTC")
    allow_any_instance_of(described_class).to receive(:set_user_time_zone)

    # TODO: remove these stubs
    allow(controller).to receive(:check_privileges).and_return(true)
    login_as user
    allow_any_instance_of(User).to receive(:role_allows?).and_return(true)
  end

  def setup_zone
    EvmSpecHelper.create_guid_miq_server_zone
  end

  shared_context "valid session" do
    let(:privilege_checker_service) { double("PrivilegeCheckerService", :valid_session?  => true) }
    let(:request_referer_service)   { double("RequestRefererService",   :allowed_access? => true) }

    before do
      allow(controller).to receive(:set_user_time_zone)
      allow(PrivilegeCheckerService).to receive(:new).and_return(privilege_checker_service)
      allow(RequestRefererService).to receive(:new).and_return(request_referer_service)
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
