class HostController < ApplicationController

  before_filter :check_privileges
  before_filter :get_session_data

  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show
    return if perfmenu_click?

    @lastaction = "show"
    @showtype = "config"

    @display = params[:display] || "main" unless control_selected?

    @host = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@host, 'Host')

    @gtl_url = "/host/show/" << @host.id.to_s << "?"
    @showtype = "config"
    set_config(@host)
    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@host)
      drop_breadcrumb( {:name=>"Hosts", :url=>"/host/show_list?page=#{@current_page}&refresh=y"}, true)
      drop_breadcrumb( {:name=>@host.name + " (Summary)", :url=>"/host/show/#{@host.id}"} )
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf","summary_only"].include?(@display)

    when "devices"
      drop_breadcrumb( {:name=>@host.name+" (Devices)", :url=>"/host/show/#{@host.id}?display=devices"} )

    when "os_info"
      drop_breadcrumb( {:name=>@host.name+" (OS Information)", :url=>"/host/show/#{@host.id}?display=os_info"} )

    when "hv_info"
      drop_breadcrumb( {:name=>@host.name+" (VM Monitor Information)", :url=>"/host/show/#{@host.id}?display=hv_info"} )

    when "network"
      drop_breadcrumb( {:name=>@host.name+" (Network)", :url=>"/host/show/#{@host.id}?display=network"} )
      build_network_tree

    when "performance"
      @showtype = "performance"
      drop_breadcrumb( {:name=>"#{@host.name} Capacity & Utilization", :url=>"/host/show/#{@host.id}?display=#{@display}&refresh=n"} )
      perf_gen_init_options               # Intialize perf chart options, charts will be generated async

    when "timeline"
      @showtype = "timeline"
      session[:tl_record_id] = params[:id] if params[:id]
      @record = find_by_id_filtered(Host, session[:tl_record_id])
      @timeline = @timeline_filter = true
      @lastaction = "show_timeline"
      tl_build_timeline                       # Create the timeline report
      drop_breadcrumb( {:name=>"Timelines", :url=>"/host/show/#{@record.id}?refresh=n&display=timeline"} )

    when "compliance_history"
      count = params[:count] ? params[:count].to_i : 10
      session[:ch_tree] = compliance_history_tree(@host, count).to_json
      session[:tree_name] = "ch_tree"
      session[:squash_open] = (count == 1)
      drop_breadcrumb( {:name=>@host.name, :url=>"/host/show/#{@host.id}"}, true )
      if count == 1
        drop_breadcrumb( {:name=>@host.name+" (Latest Compliance Check)", :url=>"/host/show/#{@host.id}?display=#{@display}"} )
      else
        drop_breadcrumb( {:name=>@host.name+" (Compliance History - Last #{count} Checks)", :url=>"/host/show/#{@host.id}?display=#{@display}"} )
      end
      @showtype = @display

    when "storage_adapters"
      drop_breadcrumb( {:name=>@host.name+" (Storage Adapters)", :url=>"/host/show/#{@host.id}?display=storage_adapters"} )
      build_sa_tree

    when "miq_proxies"
      drop_breadcrumb( {:name=>@host.name+" (Managing SmartProxies)", :url=>"/host/show/#{@host.id}?display=miq_proxies"} )
      @view, @pages = get_view(MiqProxy, :parent=>@host)  # Get the records (into a view) and the paginator
      @showtype = "miq_proxies"

    when "miq_templates", "vms"
      title = @display == "vms" ? "VMs" : "Templates"
      kls = @display == "vms" ? Vm : MiqTemplate
      drop_breadcrumb( {:name=>@host.name+" (All #{title})", :url=>"/host/show/#{@host.id}?display=#{@display}"} )
      @view, @pages = get_view(kls, :parent=>@host) # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") + " on this Host"
      end

    when "resource_pools"
      drop_breadcrumb( {:name=>@host.name+" (All Resource Pools)", :url=>"/host/show/#{@host.id}?display=resource_pools"} )
      @view, @pages = get_view(ResourcePool, :parent=>@host)  # Get the records (into a view) and the paginator
      @showtype = "resource_pools"

    when "storages"
      drop_breadcrumb( {:name=>@host.name+" (All #{ui_lookup(:tables=>"storages")})", :url=>"/host/show/#{@host.id}?display=storages"} )
      @view, @pages = get_view(Storage, :parent=>@host) # Get the records (into a view) and the paginator
      @showtype = "storages"
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other " + ui_lookup(:table=>"storages")) + " on this Host"
      end

    when "ontap_logical_disks"
      drop_breadcrumb( {:name=>@host.name+" (All #{ui_lookup(:tables=>"ontap_logical_disk")})", :url=>"/host/show/#{@host.id}?display=ontap_logicals_disks"} )
      @view, @pages = get_view(OntapLogicalDisk, :parent=>@host, :parent_method => :logical_disks)  # Get the records (into a view) and the paginator
      @showtype = "ontap_logicals_disks"

    when "ontap_storage_systems"
      drop_breadcrumb( {:name=>@host.name+" (All #{ui_lookup(:tables=>"ontap_storage_system")})", :url=>"/host/show/#{@host.id}?display=ontap_storage_systems"} )
      @view, @pages = get_view(OntapStorageSystem, :parent=>@host, :parent_method => :storage_systems)  # Get the records (into a view) and the paginator
      @showtype = "ontap_storage_systems"

    when "ontap_storage_volumes"
      drop_breadcrumb( {:name=>@host.name+" (All #{ui_lookup(:tables=>"ontap_storage_volume")})", :url=>"/host/show/#{@host.id}?display=ontap_storage_volumes"} )
      @view, @pages = get_view(OntapStorageVolume, :parent=>@host, :parent_method => :storage_volumes)  # Get the records (into a view) and the paginator
      @showtype = "ontap_storage_volumes"

    when "ontap_file_shares"
      drop_breadcrumb( {:name=>@host.name+" (All #{ui_lookup(:tables=>"ontap_file_share")})", :url=>"/host/show/#{@host.id}?display=ontap_file_shares"} )
      @view, @pages = get_view(OntapFileShare, :parent=>@host, :parent_method => :file_shares)  # Get the records (into a view) and the paginator
      @showtype = "ontap_file_shares"
    end
    @lastaction = "show"
    session[:tl_record_id] = @record.id

    # Came in from outside show_list partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def show_association(action, display_name, listicon, method, klass, association = nil)
    @host = @record = identify_record(params[:id])
    @view = session[:view]                  # Restore the view from the session to get column names for the display
    return if record_no_longer_exists?(@host, 'Host')

    @lastaction = action
    unless params[:show].nil?
      if method.kind_of?(Array)
        obj = @host
        while meth = method.shift do
          obj = obj.send(meth)
        end
        @item = obj.find(from_cid(params[:show]))
      else
        @item = @host.send(method).find(from_cid(params[:show]))
      end

      drop_breadcrumb( { :name => "#{@host.name} (#{display_name})", :url=>"/host/#{action}/#{@host.id}?page=#{@current_page}"} )
      drop_breadcrumb( { :name => @item.name,                        :url=>"/host/#{action}/#{@host.id}?show=#{@item.id}"} )
      show_item
    else
      drop_breadcrumb( { :name => @host.name,                        :url=>"/host/show/#{@host.id}"}, true )
      drop_breadcrumb( { :name => "#{@host.name} (#{display_name})", :url=>"/host/#{action}/#{@host.id}"} )
      @listicon = listicon
      if association.nil?
        show_details(klass)
      else
        show_details(klass, :association => association )
      end
    end

  end

  def filesystems
    show_association('filesystems', 'Files', 'filesystems', :filesystems, Filesystem)
  end

  def host_services
    show_association('host_services', 'Services', 'service', :host_services, SystemService)
  end

  def advanced_settings
    show_association('advanced_settings', 'Advanced Settings', 'advancedsetting', :advanced_settings, AdvancedSetting)
  end

  def firewall_rules
    show_association('firewall_rules', 'Firewall Rules', 'firewallrule', :firewall_rules, FirewallRule)
  end

  def guest_applications
    show_association('guest_applications', 'Packages', 'guest_application', :guest_applications, GuestApplication)
  end

    # Build the vm detail gtl view
  def show_details(db, options={})  # Pass in the db, parent vm is in @vm
    dbname = db.to_s.downcase
    association = options[:association] || nil

    # generate the grid/tile/list url to come back here when gtl buttons are pressed
    @gtl_url = "/host/" + @lastaction + "/" + @host.id.to_s + "?"

    @showtype = "details"
    @no_checkboxes = true
    @showlinks = true

    @view, @pages = get_view(db,
                            :parent=>@host,
                            :association=>association,
                            :dbname=>"hostitem")  # Get the records into a view & paginator


    # Came in from outside, use RJS to redraw gtl partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
#     render :update do |page|                    # Use RJS to update the display
#       page.replace_html("main_div", :partial=>"layouts/gtl", :locals=>{:action_url=>@lastaction})
#     end
      replace_gtl_main_div
    else
      render :action => 'show'
    end
  end

  def toggle_policy_profile
    if session[:policy_assignment_compressed].nil?
      session[:policy_assignment_compressed] = false
    else
      session[:policy_assignment_compressed] = ! session[:policy_assignment_compressed]
    end
    @compressed = session[:policy_assignment_compressed]
    protect_build_screen
    protect_set_db_record

    render :update do |page|                                # Use RJS to update the display
      page.replace_html("view_buttons_div", :partial=>"layouts/view_buttons")   # Replace the view buttons
      page.replace_html("main_div", :partial=>"layouts/protecting")   # Replace the main div area contents
    end
  end

  # Show the main Host list view
  def show_list
    session[:host_items] = nil
    process_show_list
  end

  def start
    redirect_to :action => 'show_list'
  end

  def new
    assert_privileges("host_new")
    @host = Host.new
    set_form_vars
    @in_a_form = true
    drop_breadcrumb( {:name=>"Add New Host", :url=>"/host/new"} )
  end

  def create
    assert_privileges("host_new")
    return unless load_edit("host_edit__new")
    get_form_vars
    case params[:button]
    when "cancel"
      render :update do |page|
        page.redirect_to :action=>'show_list', :flash_msg=>_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"Host")
      end
    when "add"
      add_host = Host.new
      set_record_vars(add_host, :validate)                        # Set the record variables, but don't save
      add_host.vmm_vendor = "unknown"
      if valid_record?(add_host) && add_host.save
        set_record_vars(add_host)                                 # Save the authentication records for this host
        AuditEvent.success(build_created_audit(add_host, @edit))
        render :update do |page|
          page.redirect_to :action=>'show_list', :flash_msg=>_("%{model} \"%{name}\" was added") % {:model=>ui_lookup(:model=>"Host"), :name=>add_host.name}
        end
        return
      else
        @in_a_form = true
        @edit[:errors].each { |msg| add_flash(msg, :error) }
        add_host.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        drop_breadcrumb( {:name=>"Add New Host", :url=>"/host/new"} )
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    when "validate"
      verify_host = Host.new
      set_record_vars(verify_host, :validate)
      @in_a_form = true
      begin
        verify_host.verify_credentials(params[:type])
      rescue StandardError=>bang
        add_flash("#{bang}", :error)
      else
        add_flash(_("Credential validation was successful"))
      end
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  def edit
    assert_privileges("host_edit")
    if session[:host_items].nil?
      @host = find_by_id_filtered(Host, params[:id])
      set_form_vars
      @in_a_form = true
      session[:changed] = false
      drop_breadcrumb( {:name=>"Edit Host '#{@host.name}'", :url=>"/host/edit/#{@host.id}"} )
      @title = "Info/Settings"
    else            #if editing credentials for multi host
      @title = "Credentials/Settings"
      if params[:selected_host]
        @host = find_by_id_filtered(Host, params[:selected_host])
      else
        @host = Host.new
      end
      set_form_vars
      @changed = true
      @showlinks = true
      @in_a_form = true
      @edit[:hostitems] = Array.new
      hostitems = Host.find(session[:host_items]).sort{|a,b| a.name <=> b.name} # Get the db records that are being tagged
      @edit[:selected_hosts] = { nil => "<Choose>" }
      hostitems.each do |h|
        @edit[:selected_hosts][h.id] = h.name
        @edit[:hostitems].push(h.id)
      end
      build_targets_hash(hostitems)
      @view = get_db_view(Host)       # Instantiate the MIQ Report view object
      @view.table = MiqFilter.records2table(hostitems, :only=>@view.cols + ['id'])
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("host_edit__#{params[:id]}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])

    render :update do |page|                    # Use JS to update the display
      if changed != session[:changed]
        session[:changed] = changed
        unless params[:id] == "new"
          page << javascript_for_miq_button_visibility(changed)
        end
      end
      unless session[:host_items].nil?
        page << "miqButtons('show');"
      end
      if @edit[:default_verify_status] != session[:host_default_verify_status]
        session[:host_default_verify_status] = @edit[:default_verify_status]
        if @edit[:default_verify_status]
          page << "miqValidateButtons('show', 'default_');"
        else
          page << "miqValidateButtons('hide', 'default_');"
        end
      end
      if @edit[:remote_verify_status] != session[:host_remote_verify_status]
        session[:host_remote_verify_status] = @edit[:remote_verify_status]
        if @edit[:remote_verify_status]
          page << "miqValidateButtons('show', 'remote_');"
        else
          page << "miqValidateButtons('hide', 'remote_');"
        end
      end
      if @edit[:ws_verify_status] != session[:host_ws_verify_status]
        session[:host_ws_verify_status] = @edit[:ws_verify_status]
        if @edit[:ws_verify_status]
          page << "miqValidateButtons('show', 'ws_');"
        else
          page << "miqValidateButtons('hide', 'ws_');"
        end
      end
      if @edit[:ipmi_verify_status] != session[:host_ipmi_verify_status]
        session[:host_ipmi_verify_status] = @edit[:ipmi_verify_status]
        if @edit[:ipmi_verify_status]
          page << "miqValidateButtons('show', 'ipmi_');"
        else
          page << "miqValidateButtons('hide', 'ipmi_');"
        end
      end
    end
  end

  def update
    assert_privileges("host_edit")
    id = params[:id] || "new"
    return unless load_edit("host_edit__#{id}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      flash = "Edit for Host \""
      @breadcrumbs.pop if @breadcrumbs
      if !session[:host_items].nil?
        flash = _("Edit of credentials for selected %s was cancelled by the user") % ui_lookup(:models=>"Host")
        #redirect_to :action => @lastaction, :display=>session[:host_display], :flash_msg=>flash
        render :update do |page|
          page.redirect_to :action=>@lastaction, :display=>session[:host_display], :flash_msg=>flash
        end
      else
        flash = _("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"Host"), :name=>@host.name}
        render :update do |page|
          page.redirect_to :action=>@lastaction, :id=>@host.id, :display=>session[:host_display], :flash_msg=>flash
        end
      end

    when "save"
      if session[:host_items].nil?
        update_host = find_by_id_filtered(Host, params[:id])
        valid_host = find_by_id_filtered(Host, params[:id])
        set_record_vars(valid_host, :validate)                      # Set the record variables, but don't save
        if valid_record?(valid_host) && set_record_vars(update_host) && update_host.save
          add_flash(_("%{model} \"%{name}\" was saved") % {:model=>ui_lookup(:model=>"host"), :name=>update_host.name})
          @breadcrumbs.pop if @breadcrumbs
          AuditEvent.success(build_saved_audit(update_host, @edit))
          session[:edit] = nil  # clean out the saved info
          session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
          render :update do |page|
            page.redirect_to :action=>"show", :id=>@host.id.to_s
          end
          return
        else
          @edit[:errors].each { |msg| add_flash(msg, :error) }
          update_host.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          drop_breadcrumb( {:name=>"Edit Host '#{@host.name}'", :url=>"/host/edit/#{@host.id}"} )
          @in_a_form = true
          session[:changed] = changed
          @changed = true
          render :update do |page|
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          end
        end
      else
        valid_host = find_by_id_filtered(Host, session[:host_items].first.to_i)
        settings, creds, verify = set_credentials_record_vars(valid_host, :validate)      # Set the record variables, but don't save
        if valid_record?(valid_host) && verify
          @error = Host.multi_host_update(session[:host_items], settings, creds)
        end
        if @error || @error.blank?
          #redirect_to :action => 'show_list', :flash_msg=>_("Credentials/Settings saved successfully")
          render :update do |page|
            page.redirect_to :action=>'show_list', :flash_msg=>_("Credentials/Settings saved successfully")
          end
        else
          drop_breadcrumb( {:name=>"Edit Host '#{@host.name}'", :url=>"/host/edit/#{@host.id}"} )
          @in_a_form = true
          session[:changed] = changed
          @changed = true
          #redirect_to :action => 'edit', :flash_msg=>@error, :flash_error =>true
          render :update do |page|
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          end
        end
      end
    when "reset"
      params[:edittype] = @edit[:edittype]    # remember the edit type
      add_flash(_("All changes have been reset"), :warning)
      @in_a_form = true
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page.redirect_to :action=>'edit', :id=>@host.id.to_s
      end
    when "validate"
      if @edit[:validate_against]     #if editing credentials for multi host
        verify_host = find_by_id_filtered(Host, @edit[:validate_against].to_i)
      else
        verify_host = find_by_id_filtered(Host, params[:id])
      end
      if session[:host_items].nil?
        set_record_vars(verify_host, :validate)
      else
        set_credentials_record_vars(verify_host, :validate)
      end
      @in_a_form = true
      @changed = session[:changed]
      begin
        require 'MiqSshUtil'
        verify_host.verify_credentials(params[:type], :remember_host=>params.has_key?(:remember_host))
      rescue Net::SSH::HostKeyMismatch => e   # Capture the Host key mismatch from the verify
        render :update do |page|
          new_url = url_for(:action=>"update", :button=>"validate", :type=>params[:type], :remember_host=>"true", :escape=>false)
          page << "if (confirm('The Host SSH key has changed, do you want to accept the new key?')) miqAjax('#{new_url}');"
        end
        return
      rescue StandardError=>bang
        add_flash("#{bang}", :error)
      else
        add_flash(_("Credential validation was successful"))
      end
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if ["vms","storages"].include?(@display)  # Were we displaying vms/storages

    if params[:pressed].starts_with?("vm_") ||      # Handle buttons from sub-items screen
        params[:pressed].starts_with?("miq_template_") ||
        params[:pressed].starts_with?("guest_") ||
        params[:pressed].starts_with?("storage_")

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      process_vm_buttons(pfx)

      scanstorage if params[:pressed] == "storage_scan"
      refreshstorage if params[:pressed] == "storage_refresh"
      tag(Storage) if params[:pressed] == "storage_tag"

      # Control transferred to another screen, so return
      return if ["host_drift", "#{pfx}_compare", "#{pfx}_tag", "#{pfx}_policy_sim",
                  "#{pfx}_retire","#{pfx}_protect","#{pfx}_ownership",
                  "#{pfx}_reconfigure","#{pfx}_retire","#{pfx}_right_size",
                  "storage_tag"].include?(params[:pressed]) && @flash_array == nil

      if !["#{pfx}_edit","#{pfx}_miq_request_new","#{pfx}_clone","#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
        @refresh_div = "main_div"
        @refresh_partial = "layouts/gtl"
        show
      end
    else                                                                        # Handle Host buttons
      params[:page] = @current_page if @current_page != nil                     # Save current page for list refresh
      @refresh_div = "main_div" # Default div for button.rjs to refresh
      drift_analysis if params[:pressed] == "common_drift"
      redirect_to :action=>"new" if params[:pressed] == "new"
      deletehosts if params[:pressed] == "host_delete"
      comparemiq if params[:pressed] == "host_compare"
      refreshhosts if params[:pressed] == "host_refresh"
      scanhosts if params[:pressed] == "host_scan"
      check_compliance_hosts if params[:pressed] == "host_check_compliance"
      analyze_check_compliance_hosts if params[:pressed] == "host_analyze_check_compliance"
      tag(Host) if params[:pressed] == "host_tag"
      assign_policies(Host) if params[:pressed] == "host_protect"
      edit_record if params[:pressed] == "host_edit"
      custom_buttons if params[:pressed] == "custom_button"
      prov_redirect if params[:pressed] == "host_miq_request_new"

      # Handle Host power buttons
      if ["host_shutdown","host_reboot","host_standby","host_enter_maint_mode","host_exit_maint_mode",
          "host_start","host_stop","host_reset"].include?(params[:pressed])
        powerbutton_hosts(params[:pressed].split("_")[1..-1].join("_")) # Handle specific power button
      end

      perf_chart_chooser if params[:pressed] == "perf_reload"
      perf_refresh_data if params[:pressed] == "perf_refresh"

      return if ["custom_button"].include?(params[:pressed])    # custom button screen, so return, let custom_buttons method handle everything
      return if ["host_tag", "host_compare", "common_drift",
                  "host_protect", "perf_reload"].include?(params[:pressed]) &&
                @flash_array == nil # Another screen showing, so return

      if @flash_array == nil && !@refresh_partial && !["host_miq_request_new"].include?(params[:pressed]) # if no button handler ran, show not implemented msg
        add_flash(_("Button not yet implemented"), :error)
        @refresh_partial = "layouts/flash_msg"
        @refresh_div = "flash_msg_div"
      elsif @flash_array && @lastaction == "show"
        @host = @record = identify_record(params[:id])
        @refresh_partial = "layouts/flash_msg"
        @refresh_div = "flash_msg_div"
      end
    end

    if @lastaction == "show" && ["custom_button","host_miq_request_new"].include?(params[:pressed])
      @host = @record = identify_record(params[:id])
    end

    if !@flash_array.nil? && params[:pressed] == "host_delete" && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg=>@flash_array[0][:message]  # redirect to build the retire screen
      end
    elsif params[:pressed].ends_with?("_edit") || ["host_miq_request_new","#{pfx}_miq_request_new",
                                                   "#{pfx}_clone","#{pfx}_migrate",
                                                   "#{pfx}_publish"].include?(params[:pressed])
      if @flash_array
        show_list
        replace_gtl_main_div
      else
        if @redirect_controller
          if ["host_miq_request_new","#{pfx}_clone","#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
            render :update do |page|
              page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id, :prov_type=>@prov_type, :prov_id=>@prov_id, :org_controller=>@org_controller, :escape=>false
            end
          else
            render :update do |page|
              page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id, :org_controller=>@org_controller
            end
          end
        else
          render :update do |page|
            page.redirect_to :action=>@refresh_partial, :id=>@redirect_id
          end
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
                page.replace_html("main_div", :partial=>"layouts/gtl", :locals=>{:action_url=>"show/#{@host.id}"})
              elsif @display == "main"
                page.replace_html("main_div", :partial=>"main")
              else
                page.replace_html(@refresh_div, :partial=>@refresh_partial)
              end
            end
          end
          page.replace_html(@refresh_div, :action=>@render_action) if @render_action != nil
        end
      end
    end
  end

  private ############################

  # Build the tree object to display the host network info
  def build_network_tree
    @tree_vms = []                   # Capture all VM ids in the tree
    host_node = TreeNodeBuilder.generic_tree_node(
      "h_#{@host.id}|",
      @host.name,
      "host.png",
      "Host: #{@host.name}",
      :expand => true
    )
    host_node[:children] = add_host_branch if @host.switches.length > 0
    @temp[:network_tree] = [host_node].to_json
    session[:tree_name]  = "network_tree"
  end

  def add_host_branch
    @host.switches.collect do |s|
      switch_node = TreeNodeBuilder.generic_tree_node(
        "s_#{s.id}|",
        s.name,
        "switch.png",
        "Switch: #{s.name}"
      )
      switch_node_children = []
      switch_node_children.concat(add_guest_devices(s)) if s.guest_devices.length > 0
      switch_node_children.concat(add_lans(s))          if s.lans.length > 0
      switch_node[:children] = switch_node_children     unless switch_node_children.empty?
      switch_node
    end
  end

  def add_guest_devices(switch)
    switch.guest_devices.collect do |p|
      TreeNodeBuilder.generic_tree_node(
        "n_#{p.id}|",
        p.device_name,
        "pnic.png",
        "Physical NIC: #{p.device_name}"
      )
    end
  end

  def add_lans(switch)
    switch.lans.collect do |l|
      lan_node = TreeNodeBuilder.generic_tree_node(
        "l_#{l.id}|",
        l.name,
        "lan.png",
        "Port Group: #{l.name}"
      )
      lan_node[:children] = add_vm_nodes(l) if l.respond_to?("vms_and_templates") &&
          l.vms_and_templates.length > 0
      lan_node
    end
  end

  def add_vm_nodes(lan)
    lan.vms_and_templates.sort_by { |l| l.name.downcase }.collect do |v|
      if v.authorized_for_user?(session[:userid])
        @tree_vms.push(v) unless @tree_vms.include?(v)
        if v.template?
          image = v.host ? "template.png" : "template-no-host.png"
        else
          image = "#{v.current_state.downcase}.png"
        end
        TreeNodeBuilder.generic_tree_node(
          "v-#{v.id}|",
          v.name,
          image,
          "VM: #{v.name} (Click to view)"
        )
      end
    end
  end

  # Build the tree object to display the host storage adapter info
  def build_sa_tree
    host_node = TreeNodeBuilder.generic_tree_node(
      "h_#{@host.id}|",
      @host.name,
      "host.png",
      "Host: #{@host.name}",
      :expand      => true,
      :style_class => "cfme-no-cursor-node"
    )
    host_node[:children] = storage_adapters_node if !@host.hardware.nil? &&
        @host.hardware.storage_adapters.length > 0
    @temp[:sa_tree] = [host_node].to_json
    session[:tree] = "sa"
    session[:tree_name] = "sa_tree"
  end

  def storage_adapters_node
    @host.hardware.storage_adapters.collect do |storage_adapter|
      storage_adapter_node = TreeNodeBuilder.generic_tree_node(
          "sa_#{storage_adapter.id}|",
          storage_adapter.device_name,
          "sa_#{storage_adapter.controller_type.downcase}.png",
          "#{storage_adapter.controller_type} Storage Adapter: #{storage_adapter.device_name}",
          :style_class => "cfme-no-cursor-node"
        )
      storage_adapter_node[:children] =
          add_miq_scsi_targets_nodes(storage_adapter) if storage_adapter.miq_scsi_targets.length > 0
      storage_adapter_node
    end
  end

  def add_miq_scsi_targets_nodes(storage_adapter)
    storage_adapter.miq_scsi_targets.collect do |scsi_target|
      name = "SCSI Target #{scsi_target.target}"
      name = name + " (#{scsi_target.iscsi_name})" unless scsi_target.iscsi_name.blank?
      target_text = name.blank? ? "[empty]" : name
      target_node = TreeNodeBuilder.generic_tree_node(
          "t_#{scsi_target.id}|",
          target_text,
          "target_scsi.png",
          "Target: #{target_text}",
          :style_class => "cfme-no-cursor-node"
        )
      target_node[:children] = add_miq_scsi_luns_nodes(scsi_target) if scsi_target.miq_scsi_luns.length > 0
      target_node
    end
  end

  def add_miq_scsi_luns_nodes(target)
    target.miq_scsi_luns.collect do |l|
      TreeNodeBuilder.generic_tree_node(
        "l_#{l.id}|",
        l.canonical_name,
        "lun.png",
        "LUN: #{l.canonical_name}",
        :style_class => "cfme-no-cursor-node"
      )
    end
  end

  # Validate the host record fields
  def valid_record?(host)
    valid = true
    @edit[:errors] = Array.new
    if !host.authentication_userid.blank? && @edit[:new][:password] != @edit[:new][:verify]
      @edit[:errors].push("Default Password and Verify Password fields do not match")
      valid = false
      @tabnum = "1"
    end
    if host.authentication_userid.blank? && (!host.authentication_userid(:remote).blank? || !host.authentication_userid(:ws).blank?)
      @edit[:errors].push("Default User ID must be entered if a Remote Login or Web Services User ID is entered")
      valid = false
      @tabnum = "1"
    end
    if !host.authentication_userid(:remote).blank? && @edit[:new][:remote_password] != @edit[:new][:remote_verify]
      @edit[:errors].push("Remote Login Password and Verify Password fields do not match")
      valid = false
      @tabnum ||= "2"
    end
    if !host.authentication_userid(:ws).blank? && @edit[:new][:ws_password] != @edit[:new][:ws_verify]
      @edit[:errors].push("Web Services Password and Verify Password fields do not match")
      valid = false
      @tabnum ||= "3"
    end
    if !host.authentication_userid(:ipmi).blank? && @edit[:new][:ipmi_password] != @edit[:new][:ipmi_verify]
      @edit[:errors].push("IPMI Password and Verify Password fields do not match")
      valid = false
      @tabnum ||= "4"
    end
    if params[:ws_port] &&  !(params[:ws_port] =~ /^\d+$/)
      @edit[:errors].push("Web Services Listen Port must be numeric")
      valid = false
    end
    if params[:log_wrapsize] && (!(params[:log_wrapsize] =~ /^\d+$/) || params[:log_wrapsize].to_i == 0)
      @edit[:errors].push("Log Wrap Size must be numeric and greater than zero")
      valid = false
    end
    return valid
  end

  # Set form variables for edit
  def set_form_vars
    @edit = Hash.new
    @edit[:host_id]    = @host.id
    @edit[:key]     = "host_edit__#{@host.id || "new"}"
    @edit[:new]     = Hash.new
    @edit[:current] = Hash.new

    @edit[:new][:name]              = @host.name
    @edit[:new][:hostname]          = @host.hostname
    @edit[:new][:ipaddress]         = @host.ipaddress
    @edit[:new][:ipmi_address]      = @host.ipmi_address
    @edit[:new][:custom_1]          = @host.custom_1
    @edit[:new][:user_assigned_os]  = @host.user_assigned_os
    @edit[:new][:scan_frequency]    = @host.scan_frequency
    @edit[:new][:mac_address]       = @host.mac_address

    @edit[:new][:default_userid]            = @host.authentication_userid.to_s
    @edit[:new][:default_password]          = @host.authentication_password.to_s
    @edit[:new][:default_verify]            = @host.authentication_password.to_s

    @edit[:new][:remote_userid]     = @host.has_authentication_type?(:remote) ? @host.authentication_userid(:remote).to_s : ""
    @edit[:new][:remote_password]   = @host.has_authentication_type?(:remote) ? @host.authentication_password(:remote).to_s : ""
    @edit[:new][:remote_verify]     = @host.has_authentication_type?(:remote) ? @host.authentication_password(:remote).to_s : ""

    @edit[:new][:ws_userid]         = @host.has_authentication_type?(:ws) ? @host.authentication_userid(:ws).to_s : ""
    @edit[:new][:ws_password]       = @host.has_authentication_type?(:ws) ? @host.authentication_password(:ws).to_s : ""
    @edit[:new][:ws_verify]         = @host.has_authentication_type?(:ws) ? @host.authentication_password(:ws).to_s : ""

    @edit[:new][:ipmi_userid]       = @host.has_authentication_type?(:ipmi) ? @host.authentication_userid(:ipmi).to_s : ""
    @edit[:new][:ipmi_password]     = @host.has_authentication_type?(:ipmi) ? @host.authentication_password(:ipmi).to_s : ""
    @edit[:new][:ipmi_verify]       = @host.has_authentication_type?(:ipmi) ? @host.authentication_password(:ipmi).to_s : ""

    # Clear saved verify status flags
    session[:host_default_verify_status]  = nil
    session[:host_remote_verify_status]   = nil
    session[:host_ws_verify_status]       = nil
    session[:host_ipmi_verify_status]     = nil
    @edit[:validate_against] = session[:edit][:validate_against] if session[:edit] && session[:edit][:validate_against] && params[:button] != "reset" #if editing credentials for multi host

    if session[:host_items].nil?
      set_verify_status
    else
      set_credentials_verify_status(@edit[:validate_against]) if @edit[:validate_against]
    end

    @edit[:current] = @edit[:new].dup
    @edit[:edittype] = params[:edittype] == nil ? "basic" : params[:edittype]
  end

  # Get variables from edit form
  def get_form_vars
    @host = @edit[:host_id] ? Host.find_by_id(@edit[:host_id]) : Host.new

    @edit[:new][:name]              = params[:name]             if params[:name]
    @edit[:new][:hostname]          = params[:hostname]         if params[:hostname]
    @edit[:new][:ipaddress]         = params[:ipaddress]        if params[:ipaddress]
    @edit[:new][:ipmi_address]      = params[:ipmi_address]     if params[:ipmi_address]
    @edit[:new][:mac_address]       = params[:mac_address]      if params[:mac_address]
    @edit[:new][:custom_1]          = params[:custom_1]         if params[:custom_1]
    @edit[:new][:user_assigned_os]  = params[:user_assigned_os] if params[:user_assigned_os]
    @edit[:new][:user_assigned_os]  = nil if @edit[:new][:user_assigned_os] == ""

#   @edit[:new][:scan_frequency] = params[:scan_frequency][:days] .to_i * 3600 * 24 + params[:scan_frequency][:hours].to_i * 3600 if params[:scan_frequency]
# Replaced above line in Sprint 34 to remove hours setting
    @edit[:new][:scan_frequency] = params[:scan_frequency][:days] .to_i * 3600 * 24 if params[:scan_frequency]

    @edit[:new][:default_userid]          = params[:default_userid]   if params[:default_userid]
    @edit[:new][:default_password]        = params[:default_password] if params[:default_password]
    @edit[:new][:default_verify]          = params[:default_verify]   if params[:default_verify]

    @edit[:new][:remote_userid]   = params[:remote_userid]    if params[:remote_userid]
    @edit[:new][:remote_password] = params[:remote_password]  if params[:remote_password]
    @edit[:new][:remote_verify]   = params[:remote_verify]    if params[:remote_verify]

    @edit[:new][:ws_userid]       = params[:ws_userid]        if params[:ws_userid]
    @edit[:new][:ws_password]     = params[:ws_password]      if params[:ws_password]
    @edit[:new][:ws_verify]       = params[:ws_verify]        if params[:ws_verify]

    @edit[:new][:ipmi_userid]     = params[:ipmi_userid]      if params[:ipmi_userid]
    @edit[:new][:ipmi_password]   = params[:ipmi_password]    if params[:ipmi_password]
    @edit[:new][:ipmi_verify]     = params[:ipmi_verify]      if params[:ipmi_verify]

    @edit[:validate_against]      = params[:validate_id]      if params[:validate_id]   #if editing credentials for multi host
    if session[:host_items].nil?
      set_verify_status
    else
      set_credentials_verify_status(@edit[:validate_against]) if @edit[:validate_against]
    end
  end

  def set_verify_status
    if @edit[:new][:default_userid].blank? || @edit[:new][:ipaddress].blank?
      @edit[:default_verify_status] = false
    else
      @edit[:default_verify_status] = (@edit[:new][:default_password] == @edit[:new][:default_verify])
    end

    if @edit[:new][:remote_userid].blank? || @edit[:new][:ipaddress].blank?
      @edit[:remote_verify_status] = false
    else
      @edit[:remote_verify_status] = (@edit[:new][:remote_password] == @edit[:new][:remote_verify])
    end

    if @edit[:new][:ws_userid].blank? || @edit[:new][:ipaddress].blank?
      @edit[:ws_verify_status] = false
    else
      @edit[:ws_verify_status] = (@edit[:new][:ws_password] == @edit[:new][:ws_verify])
    end

    if @edit[:new][:ipmi_userid].blank? || @edit[:new][:ipmi_address].blank?
      @edit[:ipmi_verify_status] = false
    else
      @edit[:ipmi_verify_status] = (@edit[:new][:ipmi_password] == @edit[:new][:ipmi_verify])
    end
  end

  def set_credentials_verify_status(id)
    if id.to_i == 0
      @edit[:default_verify_status] = @edit[:ws_verify_status] = @edit[:remote_verify_status]= @edit[:ipmi_verify_status] = false
    else
      host = find_by_id_filtered(Host, id.to_i)
      if @edit[:new][:default_userid].blank? || host.ipaddress.blank?
        @edit[:default_verify_status] = false
      else
        @edit[:default_verify_status] = (@edit[:new][:default_password] == @edit[:new][:default_verify])
      end

      if @edit[:new][:remote_userid].blank? || host.ipaddress.blank?
        @edit[:remote_verify_status] = false
      else
        @edit[:remote_verify_status] = (@edit[:new][:remote_password] == @edit[:new][:remote_verify])
      end

      if @edit[:new][:ws_userid].blank? || host.ipaddress.blank?
        @edit[:ws_verify_status] = false
      else
        @edit[:ws_verify_status] = (@edit[:new][:ws_password] == @edit[:new][:ws_verify])
      end

      if @edit[:new][:ipmi_userid].blank? || host.ipmi_address.blank?
        @edit[:ipmi_verify_status] = false
      else
        @edit[:ipmi_verify_status] = (@edit[:new][:ipmi_password] == @edit[:new][:ipmi_verify])
      end
    end
  end

  # Set record variables to new values
  def set_record_vars(host, mode = nil)
    host.name             = @edit[:new][:name]
    host.hostname         = @edit[:new][:hostname]
    host.ipaddress        = @edit[:new][:ipaddress]
    host.ipmi_address     = @edit[:new][:ipmi_address]
    host.mac_address      = @edit[:new][:mac_address]
    host.custom_1         = @edit[:new][:custom_1]
    host.user_assigned_os = @edit[:new][:user_assigned_os]
    host.scan_frequency   = @edit[:new][:scan_frequency]

#   creds = {:default=>{:userid=>nil, :password=>nil},
#             :remote=>{:userid=>nil, :password=>nil},
#             :ws=>{:userid=>nil, :password=>nil},
#             :ipmi=>{:userid=>nil, :password=>nil}}
    creds = Hash.new
    creds[:default] = {:userid => @edit[:new][:default_userid], :password => @edit[:new][:default_password]}
    creds[:remote]  = {:userid => @edit[:new][:remote_userid],  :password => @edit[:new][:remote_password]}
    creds[:ws]      = {:userid => @edit[:new][:ws_userid],      :password => @edit[:new][:ws_password]}
    creds[:ipmi]    = {:userid => @edit[:new][:ipmi_userid],    :password => @edit[:new][:ipmi_password]}
    host.update_authentication(creds, {:save=>(mode != :validate)})
    return true
  end

  # Set record variables to new values
  def set_credentials_record_vars(host, mode = nil)
    settings = Hash.new
    settings[:scan_frequency] = @edit[:new][:scan_frequency]

#   creds = {:default=>{:userid=>nil, :password=>nil},
#             :remote=>{:userid=>nil, :password=>nil},
#             :ws=>{:userid=>nil, :password=>nil},
#             :ipmi=>{:userid=>nil, :password=>nil}}
    creds = Hash.new
    creds[:default] = {:userid=>@edit[:new][:default_userid],        :password=>@edit[:new][:default_password]}        unless @edit[:new][:default_userid].blank?
    creds[:remote]  = {:userid=>@edit[:new][:remote_userid], :password=>@edit[:new][:remote_password]} unless @edit[:new][:remote_userid].blank?
    creds[:ws]      = {:userid=>@edit[:new][:ws_userid],     :password=>@edit[:new][:ws_password]}     unless @edit[:new][:ws_userid].blank?
    creds[:ipmi]    = {:userid=>@edit[:new][:ipmi_userid],   :password=>@edit[:new][:ipmi_password]}   unless @edit[:new][:ipmi_userid].blank?
    host.update_authentication(creds, {:save=>(mode != :validate) })
    return settings, creds, true
  end

  # gather up the host records from the DB
  def get_hosts
    page = params[:page].nil? ? 1 : params[:page].to_i
    @current_page = page

    @items_per_page = @settings[:perpage][@gtl_type.to_sym]   # Get the per page setting for this gtl type
    @host_pages, @hosts = paginate(:hosts, :per_page => @items_per_page, :order => @col_names[get_sort_col] + " " + @sortdir)
  end

  def get_session_data
    @title      = "Hosts"
    @layout     = "host"
    @drift_db   = "Host"
    @lastaction = session[:host_lastaction]
    @display    = session[:host_display]
    @filters    = session[:host_filters]
    @catinfo    = session[:host_catinfo]
    @base       = session[:vm_compare_base]
  end

  def set_session_data
    session[:host_lastaction] = @lastaction
    session[:host_display]    = @display unless @display.nil?
    session[:host_filters]    = @filters
    session[:host_catinfo]    = @catinfo
    session[:miq_compressed]  = @compressed  unless @compressed.nil?
    session[:miq_exists_mode] = @exists_mode unless @exists_mode.nil?
    session[:vm_compare_base] = @base
  end

end
