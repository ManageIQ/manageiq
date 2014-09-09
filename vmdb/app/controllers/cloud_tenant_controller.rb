class CloudTenantController < ApplicationController
  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if %w(vms instances images).include?(@display)
    params[:page] = @current_page unless @current_page.nil?   # Save current page for list refresh
    if params[:pressed].starts_with?("vm_") ||        # Handle buttons from sub-items screen
      params[:pressed].starts_with?("miq_template_") ||
      params[:pressed].starts_with?("guest_") ||
      params[:pressed].starts_with?("image_") ||
      params[:pressed].starts_with?("instance_")

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      process_vm_buttons(pfx)
      return if ["#{pfx}_policy_sim", "#{pfx}_compare", "#{pfx}_tag", "#{pfx}_retire",
                 "#{pfx}_protect", "#{pfx}_ownership", "#{pfx}_refresh", "#{pfx}_right_size",
                 "#{pfx}_reconfigure"].include?(params[:pressed]) &&
                  @flash_array.nil?

      unless ["#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone",
              "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
        @refresh_div = "main_div"
        @refresh_partial = "layouts/gtl"
        show
      end
    end
    render_button_partial(pfx)
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
      drop_breadcrumb({:name => @cloud_tenant.name + " (Summary)", :url => "/cloud_tenant/show/#{@cloud_tenant.id}"})
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf", "summary_only"].include?(@display)
    when "ems_cloud"
      drop_breadcrumb({:name => @cloud_tenant.name + " (#{ui_lookup(:table => "ems_cloud")}(s))", :url => "/cloud_tenant/show/#{@cloud_tenant.id}?display=ems_cloud"})
      @view, @pages = get_view(EmsCloud, :parent => @cloud_tenant)  # Get the records (into a view) and the paginator
      @showtype = "ems_cloud"
    when "instances", "images"
      table = @display == "instances" ? "vm_cloud" : "template_cloud"
      title = ui_lookup(:tables => table)
      kls   = @display == "instances" ? VmCloud : TemplateCloud
      drop_breadcrumb({:name => @cloud_tenant.name + " (All #{title})", :url => "/cloud_tenant/show/#{@cloud_tenant.id}?display=#{@display}"})
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
      drop_breadcrumb({:name => @cloud_tenant.name + " (All #{title})", :url => "/cloud_tenant/show/#{@cloud_tenant.id}?display=#{@display}"})
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

  def render_button_partial(pfx)
    if @flash_array && params[:pressed] == "#{@table_name}_delete" && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg => @flash_array[0][:message]
      end
    elsif params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new", "#{pfx}_clone",
                                                   "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
      if @redirect_controller
        if ["#{pfx}_clone", "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
          render :update do |page|
            page.redirect_to :controller => @redirect_controller,
                             :action     => @refresh_partial,
                             :id         => @redirect_id,
                             :prov_type  => @prov_type,
                             :prov_id    => @prov_id
          end
        else
          render :update do |page|
            page.redirect_to :controller => @redirect_controller, :action => @refresh_partial, :id => @redirect_id
          end
        end
      else
        render :update do |page|
          page.redirect_to :action => @refresh_partial, :id => @redirect_id
        end
      end
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render :update do |page|                    # Use RJS to update the display
          if ["vms"].include?(@display) && @refresh_div != "flash_msg_div"
            page << "miqReinitToolbar('center_tb');"
            page.replace_html("main_div", :partial => "layouts/gtl",
                                          :locals  => {:action_url => "show/#{@cloud_tenant.id}"})
          else
            page.replace_html(@refresh_div, :partial => @refresh_partial)
          end
        end
      end
    end
  end

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
