class SecurityGroupController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show_list
    process_show_list
  end

  def show
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype = "config"
    @security_group = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@security_group)

    @gtl_url = "/security_group/show/" << @security_group.id.to_s << "?"
    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@security_group)
      drop_breadcrumb({:name => "security_groups", :url => "/security_group/show_list?page=#{@current_page}&refresh=y"}, true)
      drop_breadcrumb(:name => _("%{name} (Summary)") % {:name => @security_group.name},
                      :url  => "/security_group/show/#{@security_group.id}")
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf", "summary_only"].include?(@display)

    when "ems_cloud"
      drop_breadcrumb(:name => _("%{name} (%{table}(s))") % {:name  => @security_group.name,
                                                             :table => ui_lookup(:table => "ems_cloud")},
                      :url  => "/security_group/show/#{@security_group.id}?display=ems_cloud")
      @view, @pages = get_view(ManageIQ::Providers::CloudManager, :parent => @security_group)  # Get the records (into a view) and the paginator
      @showtype = "ems_cloud"

    when "instances"
      title = ui_lookup(:tables => "vm_cloud")
      drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => @security_group.name, :title => title},
                      :url  => "/security_group/show/#{@security_group.id}?display=#{@display}")
      @view, @pages = get_view(ManageIQ::Providers::CloudManager::Vm, :parent => @security_group)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
         @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = if @view.extras[:total_count] - @view.extras[:auth_count] > 1
                        _("* You are not authorized to view other %{titles} on this %{tables}") %
                          {:titles => title.pluralize, :tables => ui_lookup(:tables => "security_group")}
                      else
                        _("* You are not authorized to view other %{title} on this %{tables}") %
                          {:title => title.singularize, :tables => ui_lookup(:tables => "security_group")}
                      end
      end
    end

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
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
      tag(SecurityGroup) if params[:pressed] == "security_group_tag"
      return if ["security_group_tag"].include?(params[:pressed]) &&
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
    @title      = _("Security Group")
    @layout     = "security_group"
    @lastaction = session[:security_group_lastaction]
    @display    = session[:security_group_display]
    @filters    = session[:security_group_filters]
    @catinfo    = session[:security_group_catinfo]
  end

  def set_session_data
    session[:security_group_lastaction] = @lastaction
    session[:security_group_display]    = @display unless @display.nil?
    session[:security_group_filters]    = @filters
    session[:security_group_catinfo]    = @catinfo
  end
end
