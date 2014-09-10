class FlavorController < ApplicationController

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
    @showtype   = "config"
    @flavor     = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@flavor)
    @gtl_url = "/flavor/show/#{@flavor.id}?"

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@flavor)
      drop_breadcrumb({:name => "Flavors", :url => "/flavor/show_list?page=#{@current_page}&refresh=y"}, true)
      drop_breadcrumb(:name => @flavor.name + " (Summary)", :url => "/flavor/show/#{@flavor.id}")
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)

    when "ems_cloud"
      drop_breadcrumb(:name => @flavor.name + " (#{ui_lookup(:table => "ems_cloud")}(s))", :url => "/flavor/show/#{@flavor.id}?display=ems_cloud")
      @view, @pages = get_view(EmsCloud, :parent => @flavor)  # Get the records (into a view) and the paginator
      @showtype = "ems_cloud"

    when "instances"
      title = ui_lookup(:tables => "vm_cloud")
      drop_breadcrumb(:name => @flavor.name + " (All #{title})", :url => "/flavor/show/#{@flavor.id}?display=#{@display}")
      @view, @pages = get_view(VmCloud, :parent => @flavor) # Get the records (into a view) and the paginator
      @showtype   = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
         @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " +
          pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") +
          " on this " + ui_lookup(:tables => "flavor")
      end
    end

    # Came in from outside show_list partial
    replace_gtl_main_div if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
  end

  def show_list
    process_show_list
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                          # Restore @edit for adv search box
    params[:display] = @display if ["images","instances"].include?(@display)  # Were we displaying vms/hosts/storages
    params[:page] = @current_page if @current_page != nil   # Save current page for list refresh

    if params[:pressed].starts_with?("image_") ||        # Handle buttons from sub-items screen
        params[:pressed].starts_with?("instance_")

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      process_vm_buttons(pfx)

      terminatevms if params[:pressed] == "instance_terminate"

      # Control transferred to another screen, so return
      return if ["#{pfx}_policy_sim","#{pfx}_compare", "#{pfx}_tag",
                 "#{pfx}_retire","#{pfx}_protect","#{pfx}_ownership",
                 "#{pfx}_refresh","#{pfx}_right_size",
                 "#{pfx}_reconfigure"].include?(params[:pressed]) &&
          @flash_array == nil

      if !["#{pfx}_edit","#{pfx}_miq_request_new","#{pfx}_clone",
           "#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
        @refresh_div = "main_div"
        @refresh_partial = "layouts/gtl"
        show                                                        # Handle VMs buttons
      end
    else
      tag(Flavor) if params[:pressed] == "flavor_tag"
      return if ["flavor_tag"].include?(params[:pressed]) &&
          @flash_array == nil # Tag screen showing, so return
    end

    check_if_button_is_implemented

    if params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new","#{pfx}_clone",
                                                "#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
      if @redirect_controller
        if ["#{pfx}_clone","#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
          render :update do |page|
            page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id, :prov_type=>@prov_type, :prov_id=>@prov_id
          end
        else
          render :update do |page|
            page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id
          end
        end
      else
        render :update do |page|
          page.redirect_to :action=>@refresh_partial, :id=>@redirect_id
        end
      end
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render :update do |page|                    # Use RJS to update the display
          if @refresh_partial != nil
            if @refresh_div == "flash_msg_div"
              page.replace(@refresh_div, :partial=>@refresh_partial)
            else
              if ["images","instances"].include?(@display) # If displaying vms, action_url s/b show
                page << "miqReinitToolbar('center_tb');"
                page.replace_html("main_div", :partial=>"layouts/gtl", :locals=>{:action_url=>"show/#{@ems.id}"})
              else
                page.replace_html(@refresh_div, :partial=>@refresh_partial)
              end
            end
          end
        end
      end
    end
  end

  private ############################

  def get_session_data
    @title      = "Flavor"
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
end
