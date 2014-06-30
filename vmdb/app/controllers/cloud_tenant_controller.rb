class CloudTenantController < ApplicationController

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype = "main"
    @cloud_tenant = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@cloud_tenant)

    @gtl_url = "/cloud_tenant/show/" << @cloud_tenant.id.to_s << "?"
    drop_breadcrumb({:name => "Cloud Tenants", :url => "/cloud_tenant/show_list?page=#{@current_page}&refresh=y"}, true)

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@cloud_tenant)
      drop_breadcrumb( {:name => @cloud_tenant.name + " (Summary)", :url => "/cloud_tenant/show/#{@cloud_tenant.id}"} )
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf","summary_only"].include?(@display)
    when "ems_cloud"
      drop_breadcrumb( {:name => @cloud_tenant.name + " (#{ui_lookup(:table => "ems_cloud")}(s))", :url => "/cloud_tenant/show/#{@cloud_tenant.id}?display=ems_cloud"} )
      @view, @pages = get_view(EmsCloud, :parent => @cloud_tenant)  # Get the records (into a view) and the paginator
      @showtype = "ems_cloud"
    when "instances", "images"
      table = @display == "instances" ? "vm_cloud" : "template_cloud"
      title = ui_lookup(:tables => table)
      kls   = @display == "instances" ? VmCloud : TemplateCloud
      drop_breadcrumb( {:name => @cloud_tenant.name + " (All #{title})", :url => "/cloud_tenant/show/#{@cloud_tenant.id}?display=#{@display}"} )
      @view, @pages = get_view(kls, :parent => @cloud_tenant)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") + " on this " + ui_lookup(:tables => "cloud_tenant")
      end
    when "security_groups"
      table = "security_groups"
      title = ui_lookup(:tables => table)
      kls   = SecurityGroup
      drop_breadcrumb( {:name => @cloud_tenant.name + " (All #{title})", :url => "/cloud_tenant/show/#{@cloud_tenant.id}?display=#{@display}"} )
      @view, @pages = get_view(kls, :parent => @cloud_tenant)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") + " on this " + ui_lookup(:tables => "cloud_tenant")
      end
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
    @title      = "Cloud Tenant"
    @layout     = "cloud_tenant"
    @lastaction = session[:cloud_tenant_lastaction]
    @display    = session[:cloud_tenant_display]
    @filters    = session[:cloud_tenant_filters]
    @catinfo    = session[:cloud_tenant_catinfo]
  end

  def set_session_data
    session[:cloud_tenant_lastaction] = @lastaction
    session[:cloud_tenant_display]    = @display unless @display.nil?
    session[:cloud_tenant_filters]    = @filters
    session[:cloud_tenant_catinfo]    = @catinfo
  end
end
