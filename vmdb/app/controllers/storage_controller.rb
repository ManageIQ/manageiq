class StorageController < ApplicationController

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show
    return if perfmenu_click?
    @display = params[:display] || "main" unless control_selected?

    @storage = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@storage)

    @gtl_url = "/storage/show/" << @storage.id.to_s << "?"
#   drop_breadcrumb({:name=>ui_lookup(:tables=>"storages"), :url=>"/storage/show_list?page=#{@current_page}&refresh=y"}, true)

    case @display
    when "all_miq_templates", "all_vms"
      title, kls = (@display == "all_vms" ? ["VMs", Vm] : ["Templates", MiqTemplate])
      drop_breadcrumb( {:name=>@storage.name+" (All Registered #{title})", :url=>"/storage/show/#{@storage.id}?display=#{@display}"} )
      @view, @pages = get_view(kls, :parent=>@storage, :association=>@display)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") + " on this Host"
      end

    when "miq_proxies"
      drop_breadcrumb( {:name=>@storage.name+" (Managing SmartProxies)", :url=>"/storage/show/#{@storage.id}?display=miq_proxies"} )
      @view, @pages = get_view(MiqProxy, :parent=>@storage) # Get the records (into a view) and the paginator
      @showtype = "miq_proxies"
      @no_checkboxes = true

    when "hosts"
      @view, @pages = get_view(Host, :parent=>@storage) # Get the records (into a view) and the paginator
      drop_breadcrumb( {:name=>@storage.name+" (All Registered Hosts)", :url=>"/storage/show/#{@storage.id}?display=hosts"} )
      @showtype = "hosts"
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other Host") + " on this " + ui_lookup(:table=>"storages")
      end

    when "download_pdf", "main", "summary_only"
      get_tagdata(@storage)
      session[:vm_summary_cool] = (@settings[:views][:vm_summary_cool] == "summary")
      @summary_view = session[:vm_summary_cool]
      drop_breadcrumb({:name=>ui_lookup(:tables=>"storages"), :url=>"/storage/show_list?page=#{@current_page}&refresh=y"}, true)
      drop_breadcrumb( {:name=>@storage.name+" (Summary)", :url=>"/storage/show/#{@storage.id}?display=main"} )
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf","summary_only"].include?(@display)

    when "performance"
      @showtype = "performance"
      drop_breadcrumb( {:name=>"#{@storage.name} Capacity & Utilization", :url=>"/storage/show/#{@storage.id}?display=#{@display}&refresh=n"} )
      perf_gen_init_options               # Intialize perf chart options, charts will be generated async

    when "storage_extents"
      drop_breadcrumb( {:name=>@storage.name+" (All #{ui_lookup(:tables=>"cim_base_storage_extent")})", :url=>"/storage/show/#{@storage.id}?display=storage_extents"} )
      @view, @pages = get_view(CimBaseStorageExtent, :parent=>@storage, :parent_method => :base_storage_extents)  # Get the records (into a view) and the paginator
      @showtype = "storage_extents"

    when "ontap_storage_systems"
      drop_breadcrumb( {:name=>@storage.name+" (All #{ui_lookup(:tables=>"ontap_storage_system")})", :url=>"/storage/show/#{@storage.id}?display=ontap_storage_systems"} )
      @view, @pages = get_view(OntapStorageSystem, :parent=>@storage, :parent_method => :storage_systems) # Get the records (into a view) and the paginator
      @showtype = "ontap_storage_systems"

    when "ontap_storage_volumes"
      drop_breadcrumb( {:name=>@storage.name+" (All #{ui_lookup(:tables=>"ontap_storage_volume")})", :url=>"/storage/show/#{@storage.id}?display=ontap_storage_volumes"} )
      @view, @pages = get_view(OntapStorageVolume, :parent=>@storage, :parent_method => :storage_volumes) # Get the records (into a view) and the paginator
      @showtype = "ontap_storage_volumes"

    when "ontap_file_shares"
      drop_breadcrumb( {:name=>@storage.name+" (All #{ui_lookup(:tables=>"ontap_file_share")})", :url=>"/storage/show/#{@storage.id}?display=ontap_file_shares"} )
      @view, @pages = get_view(OntapFileShare, :parent=>@storage, :parent_method => :file_shares) # Get the records (into a view) and the paginator
      @showtype = "ontap_file_shares"
    end
    @lastaction = "show"

    # Came in from outside show_list partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  # Show the main Storage list view
  def show_list
    process_show_list
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if ["vms","hosts"].include?(@display) # Were we displaying vms or hosts

    if params[:pressed].starts_with?("vm_") ||      # Handle buttons from sub-items screen
        params[:pressed].starts_with?("miq_template_") ||
        params[:pressed].starts_with?("guest_") ||
        params[:pressed].starts_with?("host_")

      scanhosts if params[:pressed] == "host_scan"
      analyze_check_compliance_hosts if params[:pressed] == "host_analyze_check_compliance"
      check_compliance_hosts if params[:pressed] == "host_check_compliance"
      refreshhosts   if params[:pressed] == "host_refresh"
      tag(Host) if params[:pressed] == "host_tag"
      assign_policies(Host) if params[:pressed] == "host_protect"
      edit_record  if params[:pressed] == "host_edit"
      deletehosts if params[:pressed] == "host_delete"

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      # Handle Host power buttons
      if ["host_shutdown","host_reboot","host_standby","host_enter_maint_mode","host_exit_maint_mode",
          "host_start","host_stop","host_reset"].include?(params[:pressed])
        powerbutton_hosts(params[:pressed].split("_")[1..-1].join("_")) # Handle specific power button
      else
        process_vm_buttons(pfx)
        return if ["host_tag","#{pfx}_policy_sim","host_scan","host_refresh","host_protect",
                    "#{pfx}_compare","#{pfx}_tag","#{pfx}_protect","#{pfx}_retire",
                    "#{pfx}_ownership","#{pfx}_right_size","#{pfx}_reconfigure"].include?(params[:pressed]) &&
                  @flash_array == nil   # Tag screen is showing, so return

        if !["host_edit","#{pfx}_edit","#{pfx}_miq_request_new","#{pfx}_clone","#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
          @refresh_div = "main_div"
          @refresh_partial = "layouts/gtl"
          show
          @display = "vms"
        end
      end
    else
      @refresh_div = "main_div" # Default div for button.rjs to refresh
      refreshstorage if params[:pressed] == "storage_refresh"
      tag(Storage) if params[:pressed] == "storage_tag"
      scanstorage if params[:pressed] == "storage_scan"
      deletestorages if params[:pressed] == "storage_delete"
      custom_buttons if params[:pressed] == "custom_button"
    end

    return if ["custom_button"].include?(params[:pressed])    # custom button screen, so return, let custom_buttons method handle everything
    return if ["storage_tag"].include?(params[:pressed]) && @flash_array == nil   # Tag screen showing, so return
    if !@flash_array && !@refresh_partial # if no button handler ran, show not implemented msg
      add_flash(I18n.t("flash.button.not_implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    elsif @flash_array && @lastaction == "show"
      @storage = @record = identify_record(params[:id])
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if !@flash_array.nil? && params[:pressed] == "storage_delete" && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg=>@flash_array[0][:message]  # redirect to build the retire screen
      end
    elsif params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new","#{pfx}_clone",
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
              if @display == "vms"  # If displaying vms, action_url s/b show
                page << "miqReinitToolbar('center_tb');"
                page.replace_html("main_div", :partial=>"layouts/gtl", :locals=>{:action_url=>"show/#{@storage.id}"})
              elsif @display == "main"
                page.replace_html("main_div", :partial=>"main")
              else
                page.replace_html("main_div", :partial=>@refresh_partial)
              end
            end
          end
        end
      end
    end
  end

  def show_association(action, display_name, listicon, method, klass, association = nil)
    @storage = @record = identify_record(params[:id])
    @view = session[:view]                  # Restore the view from the session to get column names for the display
    return if record_no_longer_exists?(@storage)

    @lastaction = action
    unless params[:show].nil?
      if method.kind_of?(Array)
        obj = @storage
        while meth = method.shift do
          obj = obj.send(meth)
        end
        @item = obj.find(params[:show])
      else
        @item = @storage.send(method).find(from_cid(params[:show]))
      end

      drop_breadcrumb( { :name => "#{@storage.name} (#{display_name})", :url=>"/storage/#{action}/#{@storage.id}?page=#{@current_page}"} )
      drop_breadcrumb( { :name => @item.name,                           :url=>"/storage/#{action}/#{@storage.id}?show=#{@item.id}"} )
      show_item
    else
      drop_breadcrumb( { :name => "#{@storage.name} (#{display_name})", :url=>"/storage/#{action}/#{@storage.id}"} )
      @listicon = listicon
      @showtype = "details"
      if association.nil?
        show_details(klass)
      else
        show_details(klass, :association => association )
      end
    end

  end

  def files
    show_association('files', 'All Files', 'storage_files', :storage_files, StorageFile, 'files')
  end

  def disk_files
    show_association('disk_files', 'VM Provisioned Disk Files', 'storage_disk_files', :storage_files, StorageFile, 'disk_files')
  end

  def snapshot_files
    show_association('snapshot_files', 'VM Snapshot Files', 'storage_snapshot_files', :storage_files, StorageFile, 'snapshot_files')
  end

  def vm_ram_files
    show_association('vm_ram_files', 'VM Memory Files', 'storage_memory_files', :storage_files, StorageFile, 'vm_ram_files')
  end

  def vm_misc_files
    show_association('vm_misc_files', 'Other VM Files', 'storage_other_vm_files', :storage_files, StorageFile, 'vm_misc_files')
  end

  def debris_files
    show_association('debris_files', 'Non-VM Files', 'storage_non_vm_files', :storage_files, StorageFile, 'debris_files')
  end

  # Build the vm detail gtl view
  def show_details(db, options={})  # Pass in the db, parent storage is in @storage
    association = options[:association] || nil
    condition = options[:conditions] || nil

    # generate the grid/tile/list url to come back here when gtl buttons are pressed
    @gtl_url = "/storage/" + @lastaction + "/" + @storage.id.to_s + "?"

    @showtype = "details"
    @no_checkboxes = true
    @showlinks = true

    @view, @pages = get_view(db,
                            :parent=>@storage,
                            :association=>association,
                            :conditions=>condition,
                            :dbname=>"storageitem") # Get the records into a view & paginator


    # Came in from outside, use RJS to redraw gtl partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    else
      render :action => 'show'
    end
  end

  private ############################

  # gather up the storage records from the DB
  def get_storages
    page = params[:page] == nil ? 1 : params[:page].to_i
    @current_page = page
    @items_per_page = @settings[:perpage][@gtl_type.to_sym]   # Get the per page setting for this gtl type
    @storage_pages, @storages = paginate(:storages, :per_page => @items_per_page, :order => @col_names[get_sort_col] + " " + @sortdir)
  end

# # Tag selected Storage Locations
# def tagstorage
#   storages = Array.new
#   storages = find_checked_items
#   if storages.length < 1
#     add_flash("One or more Storage Locations must be selected for tagging", :error)
#     @refresh_div = "flash_msg_div"
#     @refresh_partial = "layouts/flash_msg"
#   else
#     session[:tag_items] = storages  # Set the array of tag items
#     session[:tag_db] = Storage      # Remember the DB
#     session[:assigned_filters] = assigned_filters
#      render :update do |page|
#       page.redirect_to :controller => 'storage', :action => 'tagging'   # redirect to build the tagging screen
#     end
#   end
# end

  def get_session_data
    @title      = "Storage"
    @layout     = "storage"
    @lastaction = session[:storage_lastaction]
    @display    = session[:storage_display]
    @filters    = session[:storage_filters]
    @catinfo    = session[:storage_catinfo]
    @showtype   = session[:storage_showtype]
  end

  def set_session_data
    session[:storage_lastaction] = @lastaction
    session[:storage_display]    = @display unless @display.nil?
    session[:storage_filters]    = @filters
    session[:storage_catinfo]    = @catinfo
    session[:storage_showtype]   = @showtype
  end

end
