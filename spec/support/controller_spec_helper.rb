module ControllerSpecHelper
  def assigns(key = nil)
    if key.nil?
      @controller.view_assigns.symbolize_keys
    else
      @controller.view_assigns[key.to_s]
    end
  end

  def setup_zone
    EvmSpecHelper.create_guid_miq_server_zone
  end

  shared_context "valid session" do
    let(:privilege_checker_service) { double("PrivilegeCheckerService", :valid_session?  => true) }

    before do
      allow(controller).to receive(:set_user_time_zone)
      allow(PrivilegeCheckerService).to receive(:new).and_return(privilege_checker_service)
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
