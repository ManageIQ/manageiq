class CloudResourceQuotaController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def button
    @edit = session[:edit] # Restore @edit for adv search box
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh
    return tag("CloudResourceQuota") if params[:pressed] == 'cloud_resource_quota_tag'
    if @refresh_div == "main_div" && @lastaction == "show_list"
      replace_gtl_main_div
    else
      render_flash
    end
  end

  def show
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype = "main"
    @resource_quota = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@resource_quota)

    @gtl_url = "/cloud_resource_quota/show/#{@resource_quota.id}?"
    drop_breadcrumb({
      :name => ui_lookup(:tables => 'cloud_resource_quota'),
      :url  => "/cloud_resource_quota/show_list?page=#{@current_page}&refresh=y"
    }, true)

    case @display
    when %w(download_pdf main summary_only)
      get_tagdata(@resource_quota)
      drop_breadcrumb(
        :name => _("%{name} (Summary)") % {:name => @resource_quota.name},
        :url  => "/cloud_resource_quota/show/#{@resource_quota.id}"
      )
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    end

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def show_list
    process_show_list
  end

  private

  def get_session_data
    @title      = ui_lookup(:table => 'cloud_resource_quota')
    @layout     = "cloud_resource_quota"
    @lastaction = session[:cloud_resource_quota_lastaction]
    @display    = session[:cloud_resource_quota_display]
    @filters    = session[:cloud_resource_quota_filters]
    @catinfo    = session[:cloud_resource_quota_catinfo]
  end

  def set_session_data
    session[:cloud_resource_quota_lastaction] = @lastaction
    session[:cloud_resource_quota_display]    = @display unless @display.nil?
    session[:cloud_resource_quota_filters]    = @filters
    session[:cloud_resource_quota_catinfo]    = @catinfo
  end
end
