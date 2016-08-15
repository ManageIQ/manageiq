class MiddlewareServerGroupController < ApplicationController
  include EmsCommon
  include ContainersCommonMixin
  include MiddlewareCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def show
    clear_topology_breadcrumb
    @display = params[:display] || "main" unless control_selected?
    @lastaction = "show"
    @showtype = "main"
    @record = identify_record(params[:id])

    if @display == 'middleware_servers'
      @gtl_url = '/show'
      show_container_display(@record, 'middleware_server', MiddlewareServer)
    else
      show_container(@record, controller_name, display_name)
    end
  end
end
