class MiddlewareDatasourceController < ApplicationController
  include EmsCommon
  include ContainersCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def show_list
    process_show_list
  end

  def index
    redirect_to :action => 'show_list'
  end

  def show
    @display = params[:display] || "main" unless control_selected?
    @lastaction = "show"
    @showtype = "main"
    @record = identify_record(params[:id])
    show_container(@record, controller_name, display_name)
  end

  def listicon_image(item, _view)
    icon = item.decorate.try(:listicon_image)
    "100/#{icon}.png"
  end

  private ############################

  def display_name
    _("Middleware Datasources")
  end
end
