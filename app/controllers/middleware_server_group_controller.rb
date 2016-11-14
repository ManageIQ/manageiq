class MiddlewareServerGroupController < ApplicationController
  include EmsCommon
  include MiddlewareCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def show
    return unless init_show
    @display = params[:display] unless params[:display].nil?
    case @display
    when 'middleware_servers' then show_middleware_entities(MiddlewareServer)
    else show_middleware
    end
  end
end
