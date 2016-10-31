class ContainerNodeController < ApplicationController
  include ContainersCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def launch_cockpit
    node = identify_record(params[:id], ContainerNode)

    if node.ipaddress
      javascript_open_window(node.cockpit_url)
    else
      javascript_flash(:text => node.unsupported_reason(:launch_cockpit), :severity => :error, :spinner_off => true)
    end
  end

  menu_section :cnt
end
