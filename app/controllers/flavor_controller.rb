class FlavorController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericListMixin

  def show
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype   = "config"
    @flavor     = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@flavor)
    @gtl_url = "/show"

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@flavor)
      drop_breadcrumb({:name => _("Flavors"), :url => "/flavor/show_list?page=#{@current_page}&refresh=y"}, true)
      drop_breadcrumb(:name => _("%{name} (Summary)") % {:name => @flavor.name}, :url => "/flavor/show/#{@flavor.id}")
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)

    when "ems_cloud"
      drop_breadcrumb(:name => _("%{name} (%{table}(s))") % {:name  => @flavor.name,
                                                             :table => ui_lookup(:table => "ems_cloud")},
                      :url  => "/flavor/show/#{@flavor.id}?display=ems_cloud")
      @view, @pages = get_view(ManageIQ::Providers::CloudManager, :parent => @flavor)  # Get the records (into a view) and the paginator
      @showtype = "ems_cloud"

    when "instances"
      title = ui_lookup(:tables => "vm_cloud")
      drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => @flavor.name, :title => title},
                      :url  => "/flavor/show/#{@flavor.id}?display=#{@display}")
      @view, @pages = get_view(ManageIQ::Providers::CloudManager::Vm, :parent => @flavor) # Get the records (into a view) and the paginator
      @showtype   = @display
    end

    # Came in from outside show_list partial
    replace_gtl_main_div if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                          # Restore @edit for adv search box
    params[:display] = @display if ["images", "instances"].include?(@display)  # Were we displaying vms/hosts/storages
    params[:page] = @current_page unless @current_page.nil?   # Save current page for list refresh

    if params[:pressed].starts_with?("image_", # Handle buttons from sub-items screen
                                     "instance_")

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      process_vm_buttons(pfx)

      # Control transferred to another screen, so return
      return if ["#{pfx}_policy_sim", "#{pfx}_compare", "#{pfx}_tag",
                 "#{pfx}_retire", "#{pfx}_protect", "#{pfx}_ownership",
                 "#{pfx}_refresh", "#{pfx}_right_size",
                 "#{pfx}_reconfigure"].include?(params[:pressed]) &&
                @flash_array.nil?

      unless ["#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone",
              "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
        @refresh_div = "main_div"
        @refresh_partial = "layouts/gtl"
        show                                                        # Handle VMs buttons
      end
    else
      tag(Flavor) if params[:pressed] == "flavor_tag"
      return if ["flavor_tag"].include?(params[:pressed]) &&
                @flash_array.nil? # Tag screen showing, so return
    end

    check_if_button_is_implemented

    if params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new", "#{pfx}_clone",
                                                "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
      render_or_redirect_partial(pfx)
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render_flash
      end
    end
  end

  private ############################

  def get_session_data
    @title      = _("Flavor")
    @layout     = "flavor"
    @lastaction = session[:flavor_lastaction]
    @display    = session[:flavor_display]
    @filters    = session[:flavor_filters]
    @catinfo    = session[:flavor_catinfo]
  end

  def set_session_data
    session[:flavor_lastaction] = @lastaction
    session[:flavor_display]    = @display unless @display.nil?
    session[:flavor_filters]    = @filters
    session[:flavor_catinfo]    = @catinfo
  end

  menu_section :clo
end
