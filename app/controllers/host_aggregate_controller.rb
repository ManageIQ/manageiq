class HostAggregateController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show
    return if perfmenu_click?
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype = "config"
    @host_aggregate = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@host_aggregate)

    @gtl_url = "/show"
    drop_breadcrumb({:name => _("Host Aggregates"),
                     :url  => "/host_aggregate/show_list?page=#{@current_page}&refresh=y"}, true)
    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@host_aggregate)
      drop_breadcrumb(:name => _("%{name} (Summary)") % {:name => @host_aggregate.name},
                      :url  => "/availability_zone/show/#{@host_aggregate.id}")
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf", "summary_only"].include?(@display)

    when "performance"
      @showtype = "performance"
      drop_breadcrumb(:name => _("%{name} Capacity & Utilization") % {:name => @host_aggregate.name},
                      :url  => "/host_aggregate/show/#{@host_aggregate.id}?display=#{@display}&refresh=n")
      perf_gen_init_options # Intialize perf chart options, charts will be generated async

    when "ems_cloud"
      drop_breadcrumb(:name => _("%{name} (%{table}(s))") % {:name  => @host_aggregate.name,
                                                             :table => ui_lookup(:table => "ems_cloud")},
                      :url  => "/host_aggregate/show/#{@host_aggregate.id}?display=ems_cloud")
      @view, @pages = get_view(ManageIQ::Providers::CloudManager, :parent => @host_aggregate) # Get the records (into a view) and the paginator
      @showtype = "ems_cloud"

    when "instances"
      title = ui_lookup(:tables => "vm_cloud")
      drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => @host_aggregate.name, :title => title},
                      :url  => "/host_aggregate/show/#{@host_aggregate.id}?display=#{@display}")
      @view, @pages = get_view(ManageIQ::Providers::CloudManager::Vm, :parent => @host_aggregate) # Get the records (into a view) and the paginator
      @showtype = @display

    when "hosts"
      title = ui_lookup(:tables => "host")
      drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => @host_aggregate.name, :title => title},
                      :url  => "/host_aggregate/show/#{@host_aggregate.id}?display=#{@display}")
      @view, @pages = get_view(Host, :parent => @host_aggregate) # Get the records (into a view) and the paginator
      @showtype = @display

    when "timeline"
      @showtype = "timeline"
      session[:tl_record_id] = params[:id] if params[:id]
      @record = find_by_id_filtered(HostAggregate, session[:tl_record_id])
      @timeline = @timeline_filter = true
      @lastaction = "show_timeline"
      tl_build_timeline # Create the timeline report
      drop_breadcrumb(:name => _("Timelines"),
                      :url  => "/host_aggregate/show/#{@record.id}?refresh=n&display=timeline")
    end

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def show_list
    process_show_list
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit] # Restore @edit for adv search box

    params[:display] = @display if ["images", "instances"].include?(@display) # Were we displaying vms/hosts/storages
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh

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
        show # Handle VMs buttons
      end
    else
      tag(HostAggregate) if params[:pressed] == "host_aggregate_tag"
      return if ["host_aggregate_tag"].include?(params[:pressed]) &&
                @flash_array.nil? # Tag screen showing, so return
    end

    unless @refresh_partial # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new", "#{pfx}_clone",
                                                "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
      render_or_redirect_partial(pfx)
    elsif @refresh_div == "main_div" && @lastaction == "show_list"
      replace_gtl_main_div
    else
      render :update do |page|
        page << javascript_prologue
        unless @refresh_partial.nil?
          if @refresh_div == "flash_msg_div"
            page.replace(@refresh_div, :partial => @refresh_partial)
          elsif ["images", "instances"].include?(@display) # If displaying vms, action_url s/b show
            page << "miqSetButtons(0, 'center_tb');"
            page.replace_html("main_div", :partial => "layouts/gtl", :locals => {:action_url => "show/#{@host_aggregate.id}"})
          else
            page.replace_html(@refresh_div, :partial => @refresh_partial)
          end
        end
      end
    end
  end

  private ############################

  def get_session_data
    @title      = _("Host Aggregate")
    @layout     = "host_aggregate"
    @lastaction = session[:host_aggregate_lastaction]
    @display    = session[:host_aggregate_display]
    @filters    = session[:host_aggregate_filters]
    @catinfo    = session[:host_aggregate_catinfo]
  end

  def set_session_data
    session[:host_aggregate_lastaction] = @lastaction
    session[:host_aggregate_display]    = @display unless @display.nil?
    session[:host_aggregate_filters]    = @filters
    session[:host_aggregate_catinfo]    = @catinfo
  end
end
