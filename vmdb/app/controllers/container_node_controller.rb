class ContainerNodeController < ApplicationController
 #before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show_list
    process_show_list
  end

  def show
    return if perfmenu_click?
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype = "config"
    @container_node = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@container_node)

    @gtl_url = "/container_node/show/" << @container_node.id.to_s << "?"
    drop_breadcrumb({:name => "Availabilty Zones",
                     :url  => "/container_node/show_list?page=#{@current_page}&refresh=y"},
                    true)
    case @display
    when "download_pdf", "main", "summary_only"
      drop_breadcrumb( {:name => @container_node.name + " (Summary)",
                        :url  => "/container_node/show/#{@container_node.id}"} )
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    end

    # Came in from outside show_list partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  private ############################

  def get_session_data
    @title      = ui_lookup(:tables => "container_node")
    @layout     = "container_node"
    @table_name = request.parameters[:controller]
    @model      = Container
    @lastaction = session[:container_node_lastaction]
    @display    = session[:container_node_display]
    @filters    = session[:container_node_filters]
    @catinfo    = session[:container_node_catinfo]
  end

  def set_session_data
    session[:container_node_lastaction] = @lastaction
    session[:container_node_display]    = @display unless @display.nil?
    session[:container_node_filters]    = @filters
    session[:container_node_catinfo]    = @catinfo
  end
end
