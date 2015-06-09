# Diagnostics Accordion methods included in OpsController.rb
module OpsController::Diagnostics
  extend ActiveSupport::Concern

  def diagnostics_tree_select
    typ, id = params[:id].split("_")
    case typ
    when "server"
      @record = MiqServer.find(id)
    when "role"
      @record = ServerRole.find(id)
      @temp[:rec_status] = @record.assigned_server_roles.find_by_active(true) ? "active" : "stopped" if @record.class == ServerRole
    when "asr"
      @record = AssignedServerRole.find(id)
      @temp[:rec_status] = @record.assigned_server_roles.find_by_active(true) ? "active" : "stopped" if @record.class == ServerRole
    end
    @sb[:diag_selected_model] = @record.class.to_s
    @sb[:diag_selected_id] = @record.id
    zone = Zone.find_by_id(from_cid(x_node.split('-').last))
    refresh_screen
  end

  def restart_server
    assert_privileges("restart_server")
    begin
      svr = MiqServer.find(@sb[:selected_server_id])
      svr.restart_queue
    rescue StandardError => bang
      add_flash(_("Error during '%s': ") % "Appliance restart" << bang.message, :error)
    else
      audit = {:event=>"restart_server", :message=>"Server '#{svr.name}' restarted", :target_id=>svr.id, :target_class=>"MiqServer", :userid => session[:userid]}
      AuditEvent.success(audit)
      add_flash(_("CFME Appliance restart initiated successfully"))
    end
    render :update do |page|
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      page << "miqSparkle(false);"
    end
  end

  def pm_restart_workers
    assert_privileges("restart_workers")
    @refresh_partial = "#{@sb[:active_tab]}_tab"
    worker = MiqWorker.find_by_id(@sb[:selected_worker_id])
    wtype = worker.normalized_type
    case wtype
    #when "priority","generic"
    # begin
    #   svr = MiqServer.find(@sb[:selected_server_id])
    #   Object.const_get("Miq#{wtype.capitalize}Worker").restart_workers(@sb[:selected_server_id])
    # rescue StandardError => bang
    #   add_flash(_("Error during %s workers restart: ") % wtype << bang.message, :error)
    # else
    #   audit = {:event=>"restart_workers", :message=>"#{wtype} Workers on Server '#{svr.name}' restarted", :target_id=>svr.id, :target_class=>"MiqServer", :userid => session[:userid]}
    #   AuditEvent.success(audit)
    #   add_flash(_("%s workers restart initiated successfully") % wtype)
    # end
    when "ems_vimbroker"
      pm_reset_broker
    else
      begin
        svr = MiqServer.find(@sb[:selected_server_id])
        worker.restart
      rescue StandardError => bang
        add_flash(_("Error during '%s': ") % "workers restart" << bang.message, :error)
      else
        audit = {:event=>"restart_workers", :message=>"Worker on Server '#{svr.name}' restarted", :target_id=>svr.id, :target_class=>"MiqWorker", :userid => session[:userid]}
        AuditEvent.success(audit)
        add_flash(_("'%s' Worker restart initiated successfully") % wtype)
      end
    end
    @refresh_partial = "layouts/gtl"
    pm_get_workers
    replace_right_cell(x_node)
  end
  alias restart_workers pm_restart_workers

  def pm_refresh_workers
    assert_privileges("refresh_workers")
    @lastaction = "refresh_workers"
    @refresh_partial = "layouts/gtl"
    pm_get_workers
    replace_right_cell(x_node)
  end
  alias refresh_workers pm_refresh_workers

  def log_depot_edit
    assert_privileges("#{@sb[:selected_typ] == "miq_server" ? "" : "zone_"}log_depot_edit")
    @record = @sb[:selected_typ].classify.constantize.find_by_id(@sb[:selected_server_id])
    #@schedule = nil # setting to nil, since we are using same view for both db_back and log_depot edit
    case params[:button]
    when "cancel"
      @edit = session[:edit] = nil
      add_flash(_("Edit Log Depot settings was cancelled by the user"))
      @record = nil
      diagnostics_set_form_vars
      replace_right_cell(x_node)
    when "save"
      pfx = @sb[:active_tab] == "diagnostics_collect_logs" ? "logdepot" : "dbbackup"
      id = params[:id] ? params[:id] : "new"
      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          page << "miqSparkle(false);"
        end
        return
      end

      begin
        if params[:log_protocol].blank?
          @record.log_file_depot.try(:destroy)
        else
          new_uri = "#{params[:uri_prefix]}://#{params[:uri]}"
          build_supported_depots_for_select
          type    = Object.const_get(FileDepot.supported_depots.key(params[:log_protocol]))
          depot   = @record.log_file_depot.instance_of?(type) ? @record.log_file_depot : @record.build_log_file_depot(:type => type.to_s)
          depot.update_attributes(:uri => new_uri, :name => params[:depot_name])
          depot.update_authentication(:default => {:userid   => params[:log_userid],
                                                   :password => params[:log_password]
                                                  }) if type.try(:requires_credentials?)
          @record.save!
        end
      rescue StandardError => bang
        add_flash(_("Error during '%s': ") % "Save" << bang.message, :error)
        @changed = true
        render :update do |page|                    # Use RJS to update the display
          page.replace_html("diagnostics_collect_logs", :partial => "ops/log_collection")
        end
      else
        add_flash(_("Log Depot Settings were saved"))
        @edit = nil
        @record = nil
        diagnostics_set_form_vars
        replace_right_cell(x_node)
      end
    when "validate"
      id = params[:id] ? params[:id] : "new"
      settings = {
        :username => params[:log_userid],
        :password => params[:log_password],
        :uri      => "#{params[:uri_prefix]}://#{params[:uri]}"
      }

      begin
        type = Object.const_get(FileDepot.supported_depots.key(params[:log_protocol]))
        type.validate_settings(settings)
      rescue StandardError => bang
        add_flash(_("Error during '%s': ") % "Validate" << bang.message, :error)
      else
        add_flash(_("Log Depot Settings were validated"))
      end

      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg", :locals => {:div_num => ""})
      end
    when nil # Reset or first time in
      replace_right_cell("log_depot_edit")
    end
  end

  # Send the log in text format
  def fetch_log
    assert_privileges("fetch_log")
    disable_client_cache
    send_data($log.contents(nil,nil),
        :filename => "evm.log" )
    AuditEvent.success(:userid=>session[:userid],:event=>"download_evm_log",:message=>"EVM log downloaded")
  end

  # Send the audit log in text format
  def fetch_audit_log
    assert_privileges("fetch_audit_log")
    disable_client_cache
    send_data($audit_log.contents(nil,nil),
        :filename => "audit.log" )
    AuditEvent.success(:userid=>session[:userid],:event=>"download_audit_log",:message=>"Audit log downloaded")
  end

  # Send the production log in text format
  def fetch_production_log
    assert_privileges("fetch_production_log")
    disable_client_cache
    send_data($rails_log.contents(nil,nil),
              :filename => "#{@sb[:rails_log].downcase}.log" )
    AuditEvent.success(:userid=>session[:userid],:event=>"download_#{@sb[:rails_log].downcase}_log",:message=>"#{@sb[:rails_log]} log downloaded")
  end

  def refresh_log
    assert_privileges("refresh_log")
    @log = $log.contents(120,1000)
    @temp[:selected_server] = MiqServer.find(from_cid(x_node.split("-").last).to_i)
    add_flash(_("Logs for this CFME Server are not available for viewing"), :warning)  if @log.blank?
    render :update do |page|                    # Use JS to update the display
      page.replace_html("diagnostics_evm_log", :partial=>"diagnostics_evm_log_tab")
      page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
    end
  end

  def refresh_audit_log
    assert_privileges("refresh_audit_log")
    @log = $audit_log.contents(nil,1000)
    @temp[:selected_server] = MiqServer.find(from_cid(x_node.split("-").last).to_i)
    add_flash(_("Logs for this CFME Server are not available for viewing"), :warning)  if @log.blank?
    render :update do |page|                    # Use JS to update the display
      page.replace_html("diagnostics_audit_log", :partial=>"diagnostics_audit_log_tab")
      page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
    end
  end

  def refresh_production_log
    assert_privileges("refresh_production_log")
    @log = $rails_log.contents(nil,1000)
    @temp[:selected_server] = MiqServer.find(from_cid(x_node.split("-").last).to_i)
    add_flash(_("Logs for this CFME Server are not available for viewing"), :warning)  if @log.blank?
    render :update do |page|                    # Use JS to update the display
      page.replace_html("diagnostics_production_log", :partial=>"diagnostics_production_log_tab")
      page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
    end
  end

  def cu_repair_field_changed
    return unless load_edit("curepair_edit__new","replace_cell__explorer")
    @temp[:selected_server] = Zone.find_by_id(@sb[:selected_server_id])
    cu_repair_get_form_vars
    render :update do |page|                    # Use JS to update the display
      page.replace("flash_msg_divcu_repair", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"cu_repair"})
      page.replace_html("diagnostics_cu_repair", :partial=>"diagnostics_cu_repair_tab")
      page << "miq_cal_dateFrom = null;"
      page << "miq_cal_dateTo = new Date();"
      page << "miqBuildCalendar();"
      if @edit[:new][:start_date] == "" || @edit[:new][:end_date] == ""
        page << javascript_for_miq_button_visibility(false)
      else
        page << javascript_for_miq_button_visibility(true)
      end
      page << "miqSparkle(false);"
    end
  end

  def cu_repair
    return unless load_edit("curepair_edit__new","replace_cell__explorer")
    if @edit[:new][:end_date].to_time < @edit[:new][:start_date].to_time
      add_flash(_("End Date cannot be greater than Start Date"),:error)
    else
      # converting string to time, and then converting into user selected timezone
      from =  "#{@edit[:new][:start_date]} #{@edit[:new][:start_hour]}:#{@edit[:new][:start_min]}:00".to_time.in_time_zone(@edit[:new][:timezone])
      to =  "#{@edit[:new][:end_date]} #{@edit[:new][:end_hour]}:#{@edit[:new][:end_min]}:00".to_time.in_time_zone(@edit[:new][:timezone])
      selected_zone = Zone.find_by_id(from_cid(x_node.split('-').last))
      begin
        Metric::Capture.perf_capture_gap_queue(from, to, selected_zone)
      rescue StandardError => bang
        add_flash(_("Error during '%s': ") % "C & U Gap Collection" << bang.message, :error)  # Push msg and error flag
      else
        @edit[:new][:start_date] = @edit[:new][:end_date] = ""
        add_flash(_("%s successfully initiated") % "C & U Gap Collection")
      end
    end

    render :update do |page|                    # Use JS to update the display
      page.replace("flash_msg_divcu_repair", :partial => "layouts/flash_msg", :locals=>{:div_num=>"cu_repair"})
      page.replace_html("diagnostics_cu_repair", :partial=>"diagnostics_cu_repair_tab")
      page << "miq_cal_dateFrom = null;"
      page << "miq_cal_dateTo = new Date();"
      page << "miqBuildCalendar();"
      page << "miqSparkle(false);"
      #disable button
      page << javascript_for_miq_button_visibility(false)
    end
  end

  def replication_reset
    begin
      MiqReplicationWorker.reset_replication
    rescue StandardError => bang
      add_flash(_("Error during '%s': ") % "Reset/synchronization process" << bang.message, :error)
    else
      add_flash(_("%s successfully initiated") % "Reset/synchronization process")
    end
    render :update do |page|
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
    end
  end

  def replication_reload
    @temp[:selected_server] = MiqRegion.my_region
    @refresh_div = "diagnostics_replication"
    @refresh_partial = "diagnostics_replication_tab"
  end

  def db_backup_form_field_changed
    schedule     = MiqSchedule.find_by_id(params[:id])
    depot        = schedule.file_depot
    uri_settings = depot.try(:[], :uri).to_s.split("://")
    render :json => {
      :depot_name   => depot.try(:name),
      :uri          => uri_settings[1],
      :uri_prefix   => uri_settings[0],
      :log_userid   => depot.try(:authentication_userid),
      :log_password => depot.try(:authentication_password),
      :log_verify   => depot.try(:authentication_password),
    }
  end

  def db_backup
    if params[:backup_schedule].present?
      @schedule = MiqSchedule.find_by_id(params[:backup_schedule])
    else
      @schedule = MiqSchedule.new(:userid => session[:userid])
      @schedule.adhoc = true
      @schedule.enabled = false
      @schedule.name = "__adhoc_dbbackup_#{Time.now}__"
      @schedule.description = "Adhoc DB Backup at #{Time.now}"
      @schedule.run_at ||= {}
      run_at = create_time_in_utc("00:00:00")
      @schedule.run_at[:start_time] = "#{run_at} Z"
      @schedule.run_at[:tz] = nil
      @schedule.run_at[:interval] ||= {}
      @schedule.run_at[:interval][:unit] = "Once".downcase
    end
    @schedule.sched_action = {:method=>"db_backup"}
    if @flash_array
      render :update do |page|
        page.replace("flash_msg_divvalidate", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"validate"})
        page << "miqSparkle(false);"
      end
      return
    end

    schedule_set_record_vars(@schedule)
    schedule_validate?(@schedule)
    if @schedule.valid? && !flash_errors? && @schedule.save
      @schedule.run_adhoc_db_backup
      add_flash(_("%s successfully initiated") % "Database Backup")
      diagnostics_set_form_vars
      render :update do |page|                    # Use RJS to update the display
        page.replace("flash_msg_divdatabase", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"database"})
        page.replace_html("diagnostics_database", :partial=>"diagnostics_database_tab")
        page << "miqSparkle(false);"
      end
    else
      @schedule.errors.each do |field,msg|
        add_flash("#{field.to_s.capitalize} #{msg}", :error)
      end
      render :update do |page|                    # Use RJS to update the display
        page.replace("flash_msg_divdatabase", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"database"})
        page << "miqSparkle(false);"
      end
    end
  end

  def log_collection_form_fields
    assert_privileges("#{@sb[:selected_typ] == "miq_server" ? "" : "zone_"}log_depot_edit")
    @record = @sb[:selected_typ].classify.constantize.find_by_id(@sb[:selected_server_id])
    log_depot = @record.log_file_depot
    if log_depot
      log_depot_json = build_log_depot_json(log_depot)
    else
      log_depot_json = build_empty_log_depot_json
    end
    rh_dropbox_json = build_rh_dropbox_json
    log_depot_json.merge!(rh_dropbox_json)

    render :json => log_depot_json
  end

  def build_log_depot_json(log_depot)
    prefix, uri = log_depot[:uri].to_s.split('://')
    klass = @record.log_file_depot.try(:class)
    protocol = Dictionary.gettext(klass.name, :type => :model, :notfound => :titleize) if klass.present?

    log_depot_json = {:depot_name   => log_depot[:name],
                      :uri          => uri,
                      :uri_prefix   => prefix,
                      :log_userid   => log_depot.authentication_userid,
                      :log_password => log_depot.authentication_password,
                      :log_verify   => log_depot.authentication_password,
                      :log_protocol => protocol
    }
    log_depot_json
  end

  def build_empty_log_depot_json
    log_depot_json = {:depot_name   => '',
                      :uri          => '',
                      :uri_prefix   => '',
                      :log_userid   => '',
                      :log_password => '',
                      :log_verify   => '',
                      :log_protocol => ''
    }
    log_depot_json
  end

  def build_rh_dropbox_json
    rh_dropbox = FileDepotFtpAnonymousRedhatDropbox.new
    rh_dropbox_json = {:rh_dropbox_depot_name => rh_dropbox.name,
                       :rh_dropbox_uri        => rh_dropbox.uri.split('://')[1]
    }
    rh_dropbox_json
  end

  def db_gc_collection
    begin
      MiqSchedule.run_adhoc_db_gc(:userid => session[:userid])
    rescue StandardError => bang
      add_flash(_("Error during '%s': ") % "Database Garbage Collection" << bang.message, :error)
    else
      add_flash(_("%s successfully initiated") % "Database Garbage Collection")
    end
    render :update do |page|                    # Use RJS to update the display
      page.replace("flash_msg_divdatabase", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"database"})
      page << "miqSparkle(false);"
    end
  end

  # to delete orphaned records for user that was delete from db
  def orphaned_records_delete
    begin
      MiqReportResult.delete_by_userid(params[:userid])
    rescue StandardError => bang
      add_flash(_("Error during Orphaned Records delete for user %s: ") % params[:userid] << bang.message, :error)
      render :update do |page|                    # Use RJS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page << "miqSparkle(false);"
      end
    else
      audit = {:event=>"orphaned_record_delete", :message=>"Orphaned Records deleted for userid [#{params[:userid]}]", :target_id=>params[:userid], :target_class=>"MiqReport", :userid => session[:userid]}
      AuditEvent.success(audit)
      add_flash(_("Orphaned Records for userid %s were successfully deleted") % params[:userid])
      orphaned_records_get
      render :update do |page|                    # Use JS to update the display
        page.replace_html 'diagnostics_orphaned_data', :partial => 'diagnostics_savedreports'
      end
    end
  end

  def diagnostics_server_list
    @lastaction = "diagnostics_server_list"
    @force_no_grid_xml = true
    if x_node.split("-").first == "z"
      zone = Zone.find_by_id(from_cid(x_node.split("-").last))
      @view, @pages = get_view(MiqServer, :conditions=>["zone_id=?", zone.id]) # Get the records (into a view) and the paginator
    else
      @view, @pages = get_view(MiqServer) # Get the records (into a view) and the paginator
    end
    @no_checkboxes = @showlinks = true
    @items_per_page = ONE_MILLION
    @current_page = @pages[:current] if @pages != nil # save the current page number

    # Came in from outside show_list partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page]
      render :update do |page|
        page.replace_html("gtl_div", :partial=>"layouts/x_gtl", :locals=>{:action_url=>"diagnostics_server_list"})
        page.replace_html("paging_div", :partial=>"layouts/x_pagingcontrols")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  def diagnostics_worker_selected
    @explorer = true
    @sb[:selected_worker_id] = params[:id]
    get_workers
    @sb[:center_tb_filename] = center_toolbar_filename
    c_buttons, c_xml = build_toolbar_buttons_and_xml(@sb[:center_tb_filename])
    render :update do |page|
      #page.replace_html("main_div", :partial=>"layouts/gtl")
      page.replace_html(@sb[:active_tab], :partial=>"#{@sb[:active_tab]}_tab")
      if c_buttons && c_xml
        page << "dhxLayoutB.cells('a').expand();"
        page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
        page << javascript_show_if_exists("center_buttons_div")
      else
        page << "dhxLayoutB.cells('a').collapse();"
        page << javascript_hide_if_exists("center_buttons_div")
      end
      page << "dhxLayoutB.cells('a').collapse();" if @sb[:center_tb_filename] == "blank_view_tb"
    end
  end

  private ############################

  def log_depot_reset_form_vars
    @edit[:protocol]           = nil
    @edit[:new][:depot_name]   = nil
    @edit[:new][:uri]          = nil
    @edit[:new][:log_userid]   = nil
    @edit[:new][:log_password] = nil
    @edit[:new][:log_verify]   = nil
  end

  def file_depot_reset_form_vars
    if @edit[:protocol].present?
      klass = Object.const_get(@edit[:protocols_hash].key(@edit[:protocol]))
      depot = @record.log_file_depot.instance_of?(klass) ? @record.log_file_depot : klass.new
      @edit[:new][:requires_credentials] = klass.try(:requires_credentials?)
      @edit[:new][:uri_prefix]           = klass.try(:uri_prefix)
      @edit[:new][:depot_name]           = depot.name
      @edit[:new][:uri]                  = depot.uri.to_s.split('://').last
      @edit[:new][:log_userid]           = depot.authentication_userid
      @edit[:new][:log_password]         = depot.authentication_password
      @edit[:new][:log_verify]           = depot.authentication_password
    else
      log_depot_reset_form_vars
    end
  end

  def log_depot_get_form_vars
    unless @schedule || (@sb["active_tree"] == :diagnostics_tree && @sb["active_tab"] == "diagnostics_database")
      @record = @sb[:selected_typ].classify.constantize.find_by_id(@sb[:selected_server_id])
    end
    @prev_uri_prefix = @edit[:new][:uri_prefix]
    @prev_protocol   = @edit[:protocol]
    # @edit[:protocol] holds the current value of the selector so that it is not reset
    # when _field_changed is called
    @edit[:protocol] = params[:log_protocol].presence if params[:log_protocol]
    if @sb[:active_tab] == "diagnostics_collect_logs"
      file_depot_reset_form_vars if @prev_protocol != @edit[:protocol]
    else
      @edit[:new][:uri_prefix] = @edit[:protocols_hash].invert[params[:log_protocol]] if params[:log_protocol]
      @edit[:new][:requires_credentials] = @edit[:new][:uri_prefix] != "nfs"
    end

    @edit[:new][:depot_name] = params[:depot_name] if params[:depot_name]
    if @edit[:new][:uri_prefix].in?([nil, "nfs"]) || params[:backup_schedule] == ""
      @edit[:new][:uri]          = params[:uri] if params[:uri]
      @edit[:new][:log_userid]   = nil
      @edit[:new][:log_password] = nil
      @edit[:new][:log_verify]   = nil
    else
      @edit[:new][:uri]          = params[:uri] if params[:uri]
      @edit[:new][:log_userid]   = params[:log_userid].blank? ? nil : params[:log_userid] if params[:log_userid]
      @edit[:new][:log_password] = params[:log_password].blank? ? nil : params[:log_password] if params[:log_password]
      @edit[:new][:log_verify]   = params[:log_verify].blank? ? nil : params[:log_verify] if params[:log_verify]
    end
  end

  # Build the Utilization screen for a server
  def diagnostics_build_perf
    @record = MiqServer.find_by_id(@sb[:selected_server_id])
    if @record && @record.vm
      s, e = @record.vm.first_and_last_capture
      unless s.nil? || e.nil?
        @sb[:record_class] = @record.class.to_s
        @sb[:record_id] = @record.id
        perf_gen_init_options(refresh="y")  # Intialize perf chart options, charts will be generated async
      end
    end
  end

  # Build the Timeline screen for a server
  def diagnostics_build_timeline
    @record = MiqServer.find_by_id(@sb[:selected_server_id])
    if @record && @record.vm
      @sb[:record_class] = @record.class.to_s
      @sb[:record_id] = @record.id
      session[:tl_record_id] = @record.vm.id
      @timeline = true
      tl_build_timeline                       # Create the timeline report
    end
  end

  def cu_repair_set_form_vars
    @timezone_offset = get_timezone_offset("server")
    @in_a_form = true
    @edit ||= Hash.new
    @edit[:new] ||= Hash.new
    @edit[:key] = "curepair_edit__new"
    @edit[:new][:start_hour] = "00"
    @edit[:new][:start_min] = "00"
    #@edit[:new][:start_date] = "#{f.month}/#{f.day}/#{f.year}" # Set the start date
    @edit[:new][:start_date] = ""

    @edit[:new][:end_hour] = "23"
    @edit[:new][:end_min] = "59"
    #@edit[:new][:end_date] = "#{t.month}/#{t.day}/#{t.year}" # Set the start date
    @edit[:new][:end_date] = ""

    tz = MiqServer.my_server.get_config("vmdb").config[:server][:timezone]
    @edit[:new][:timezone] = tz.blank? ? "UTC" : tz
  end

  def cu_repair_get_form_vars
    @edit[:new][:timezone] = params[:cu_repair_tz] if params[:cu_repair_tz]
    @edit[:new][:start_date] = params[:miq_date_1] if params[:miq_date_1]
    @edit[:new][:end_date] = params[:miq_date_2] if params[:miq_date_2]
    if @edit[:new][:start_date] != "" && (@edit[:new][:end_date] == "" || @edit[:new][:end_date].to_time < @edit[:new][:start_date].to_time)
      @edit[:new][:end_date] = @edit[:new][:start_date]
    end
  end

  def pm_reset_broker
    @lastaction = "reset_broker"
    ems = ExtManagementSystem.all
    ems.each do |ms|
      begin
        ms.reset_vim_cache_queue              # Run the task
      rescue StandardError => bang
        add_flash(_("Error during '%s': ") % "Clear Connection Broker cache" << bang.message, :error)
      else
        audit = {:event=>"reset_broker", :message=>"Connection Broker cache cleared successfully", :target_id=>ms.id, :target_class=>"ExtManagementSystem", :userid => session[:userid]}
        AuditEvent.success(audit)
        add_flash(_("Connection Broker cache cleared successfully"))
      end
    end
    pm_get_workers
  end

  # Collect the current logs from the selected zone or server
  def logs_collect(options={})
    options[:support_case] = params[:support_case] if params[:support_case]
    obj, id  = x_node.split("-")
    assert_privileges("#{obj == "z" ? "zone_" : ""}collect_logs")
    klass    = obj == "svr" ? MiqServer : Zone
    instance = @temp[:selected_server] = klass.find(from_cid(id).to_i)
    if !instance.active?
      add_flash(_("Cannot start log collection, requires a started server"), :error)
    elsif instance.log_collection_active_recently?
      add_flash(_("Cannot start log collection, a log collection is already in progress within this scope"), :error)
    else
      begin
        instance.synchronize_logs(session[:userid], options)
      rescue StandardError => bang
        add_flash(_("Log collection error returned: ") << bang.message, :error)
      else
        add_flash(_("Log collection for CFME %{object_type} %{name} has been initiated") % {:object_type => klass.name, :name => instance.display_name})
      end
    end
    get_node_info(x_node)
    replace_right_cell(x_node)
  end

  # Reload the selected node and redraw the screen via ajax
  def refresh_server_summary
    assert_privileges("refresh_server_summary")
    get_node_info(x_node)
    replace_right_cell(x_node)
  end

  def pm_get_workers
    @sb[:selected_worker_id] = nil
    get_workers
  end

  def get_workers
    @lastaction = "pm_workers_list"
    @force_no_grid_xml = true
    @no_checkboxes = true
    @gtl_type = "list"
    @ajax_paging_buttons = true
    @embedded = @pages = false
    @showlinks = true
    status = ["started","ready","working"]
    #passing all_pages option to show all records on same page
    @view, @pages = get_view(MiqWorker, :conditions => ["(miq_server_id = ? and status IN (?))", @sb[:selected_server_id], status], :all_pages=>true) # Get the records (into a view) and the paginator
    #setting @embedded and @pages to nil, we don't want to show sorting/paging bar on the screen'
    @embedded = @pages = nil
  end

  def role_start
    assert_privileges("role_start")
    if @sb[:diag_selected_model] != "AssignedServerRole"
      add_flash(_("%s is not allowed for the selected item") % "Start", :error)
    else
      asr = AssignedServerRole.find(@sb[:diag_selected_id])
      begin
        asr.activate_in_role_scope
      rescue StandardError => bang
        add_flash(bang, :error)
      else
        add_flash(_("%s successfully initiated") % "Start")
      end
    end
    refresh_screen
  end

  def role_suspend
    assert_privileges("role_suspend")
    if @sb[:diag_selected_model] != "AssignedServerRole"
      add_flash(_("%s is not allowed for the selected item") % "Suspend", :error)
    else
      asr = AssignedServerRole.find(@sb[:diag_selected_id])
      begin
        asr.deactivate_in_role_scope
      rescue StandardError => bang
        add_flash(bang, :error)
      else
        add_flash(_("%s successfully initiated") % "Suspend", :error)
      end
    end
    refresh_screen
  end

  # Delete all selected server
  def delete_server
    assert_privileges("delete_server")
    servers = Array.new
    if @sb[:diag_selected_id].nil?
      add_flash(_("%s no longer exists") % ui_lookup(:table=>"evm_server"), :error)
    else
      servers.push(@sb[:diag_selected_id])
    end
    process_servers(servers, "destroy") if ! servers.empty?
    add_flash(_("The selected %s was deleted") % ui_lookup(:table=>"evm_server")) if @flash_array == nil
    refresh_screen
  end

  # Common Server button handler routines
  def process_servers(servers, task)
    MiqServer.find_all_by_id(servers, :order => "lower(name)").each do |svr|
      id = svr.id
      svr_name = svr.name
      if task == "destroy"
        audit = {:event=>"svr_record_delete", :message=>"[#{svr_name}] Record deleted", :target_id=>id, :target_class=>"MiqServer", :userid => session[:userid]}
      end
      begin
        svr.send(task.to_sym) if svr.respond_to?(task)    # Run the task
      rescue StandardError => bang
        add_flash(_("%{model} \"%{name}\": Error during '%{task}': ") % {:model=>ui_lookup(:model=>"MiqServer"), :name=>svr_name, :task=>task} << bang.message,
                  :error)
      else
        if task == "destroy"
          AuditEvent.success(audit)
          add_flash(_("%{model} \"%{name}\": Delete successful") % {:model=>ui_lookup(:model=>"MiqServer"), :name=>"#{svr_name} [#{svr.id}]"})
        else
          add_flash(_("%{model} \"%{name}\": %{task} successfully initiated") % {:model=>ui_lookup(:model=>"MiqServer"), :name=>"#{svr_name} [#{svr.id}]", :task=>task})
        end
      end
    end
  end

  def promote_server
    assert_privileges("promote_server")
    if @sb[:diag_selected_model] != "AssignedServerRole"
      add_flash(_("Setting priority is not allowed for the selected item"), :error)
    else
      asr = AssignedServerRole.find(@sb[:diag_selected_id])
      begin
        asr.set_priority(asr.priority - 1)
      rescue StandardError => bang
        add_flash(bang, :error)
      else
        priority = asr.priority == 1 ? "primary" : (asr.priority == 2 ? "secondary" : "normal")
        add_flash(_("CFME Server \"%{name}\" set as %{priority} for Role \"%{role_description}\"") % {:name=>asr.miq_server.name, :priority=>priority, :role_description=>asr.server_role.description})
      end
    end
    refresh_screen
  end

  def demote_server
    assert_privileges("demote_server")
    if @sb[:diag_selected_model] != "AssignedServerRole"
      add_flash(_("Setting priority is not allowed for the selected item"), :error)
    else
      asr = AssignedServerRole.find(@sb[:diag_selected_id])
      begin
        asr.set_priority(asr.priority + 1)
      rescue StandardError => bang
        add_flash(bang, :error)
      else
        priority = asr.priority == 1 ? "primary" : (asr.priority == 2 ? "secondary" : "normal")
        add_flash(_("CFME Server \"%{name}\" set as %{priority} for Role \"%{role_description}\"") % {:name=>asr.miq_server.name, :priority=>priority, :role_description=>asr.server_role.description})
      end
    end
    refresh_screen
  end

  # Reload the selected node and redraw the screen via ajax
  def refresh_screen
    @explorer = true
    if params[:pressed] == "delete_server"
      @sb[:diag_selected_id] = nil
      settings_build_tree
      diagnostics_build_tree
      analytics_build_tree
    end
    if x_node == "root"
      parent = MiqRegion.my_region
    else
      parent = Zone.find_by_id(from_cid(x_node.split('-').last))
    end
    @temp[:server_tree] = build_server_tree(parent).to_json
    @sb[:center_tb_filename] = center_toolbar_filename
    c_buttons, c_xml = build_toolbar_buttons_and_xml(@sb[:center_tb_filename])
    render :update do |page|
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      page.replace("selected_#{@sb[:active_tab].split('_').last}_div", :partial=>"selected")
      #   Replace tree
      if params[:pressed] == "delete_server"
        page.replace("settings_tree_div", :partial=>"tree", :locals => {:name => "settings_tree"})
        page.replace("diagnostics_tree_div", :partial=>"tree", :locals => {:name => "diagnostics_tree"})
        if get_vmdb_config[:product][:analytics]
          page.replace("analytics_tree_div", :partial=>"tree", :locals => {:name => "analytics_tree"})
        end
        nodes = x_node.split("-")
        nodes.pop
        page << "cfmeDynatree_activateNodeSilently('<%= x_active_tree %>', '<%= x_node %>');"
      end
      if params[:action] == "x_button"
        kls = x_node.split("-").first == "z" ? Zone : MiqServer
        @temp[:selected_server] = kls.find(from_cid(x_node.split("-").last))
        page.replace("zone_tree_div", :partial=>"zone_tree")
      end
      if c_buttons && c_xml
        page << "dhxLayoutB.cells('a').expand();"
        page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
        page << javascript_show_if_exists("center_buttons_div")
      else
        page << "dhxLayoutB.cells('a').collapse();"
        page << javascript_hide_if_exists("center_buttons_div")
      end
      page << "dhxLayoutB.cells('a').collapse();" if @sb[:center_tb_filename] == "blank_view_tb"
    end
  end

  # Reload the selected node and redraw the screen via ajax
  def reload_server_tree
    assert_privileges("reload_server_tree")
    if x_node == "root"
      parent = MiqRegion.my_region
    else
      parent = Zone.find_by_id(from_cid(x_node.split('-').last))
    end
    @temp[:server_tree] = build_server_tree(parent).to_json
    render :update do |page|
      #   Replace tree
      page.replace("selected_#{@sb[:active_tab].split('_').last}_div", :partial=>"selected")
    end
  end

  def diagnostics_set_form_vars
    active_node = x_node
    if active_node && active_node.split('-').first == "z"
      @record = @temp[:selected_server] = Zone.find_by_id(from_cid(active_node.split('-').last))
      @sb[:selected_server_id] = @temp[:selected_server].id
      @sb[:selected_typ] = "zone"
      if @temp[:selected_server].miq_servers.length >= 1 &&
          ["diagnostics_roles_servers","diagnostics_servers_roles"].include?(@sb[:active_tab])
        @temp[:server_tree] = build_server_tree(@temp[:selected_server]).to_json
      else
        @temp[:server_tree] = nil
      end
      cu_repair_set_form_vars if @sb[:active_tab] == "diagnostics_cu_repair"
      diagnostics_server_list if @sb[:active_tab] == "diagnostics_server_list"
      @right_cell_text = @sb[:my_zone] == @temp[:selected_server].name ?
        _("%{typ} %{model} \"%{name}\" (current)") % {:typ=>"Diagnostics", :name=>@temp[:selected_server].description, :model=>ui_lookup(:model=>@temp[:selected_server].class.to_s)} :
        _("%{typ} %{model} \"%{name}\"") % {:typ=>"Diagnostics", :name=>@temp[:selected_server].description, :model=>ui_lookup(:model=>@temp[:selected_server].class.to_s)}
    elsif x_node == "root"
      if @sb[:active_tab] == "diagnostics_zones"
        @zones = Zone.in_my_region.all
      elsif ["diagnostics_roles_servers","diagnostics_servers_roles"].include?(@sb[:active_tab])
        @temp[:selected_server] = MiqRegion.my_region
        @sb[:selected_server_id] = @temp[:selected_server].id
        @sb[:selected_typ] = "miq_region"
        if @temp[:selected_server].miq_servers.length >= 1
          @temp[:server_tree] = build_server_tree(@temp[:selected_server]).to_json
        else
          @temp[:server_tree] = nil
        end
      elsif @sb[:active_tab] == "diagnostics_replication"     # Replication tab
        @temp[:selected_server] = MiqRegion.my_region
      elsif @sb[:active_tab] == "diagnostics_database"
        build_backup_schedule_options_for_select
        build_db_options_for_select
      elsif @sb[:active_tab] == "diagnostics_orphaned_data"
        orphaned_records_get
      elsif @sb[:active_tab] == "diagnostics_server_list"
      diagnostics_server_list
      end
      @right_cell_text = _("%{typ} %{model} \"%{name}\"") % {:typ=>"Diagnostics", :name=>"#{MiqRegion.my_region.description} [#{MiqRegion.my_region.region}]", :model=>ui_lookup(:model=>"MiqRegion")}
    elsif active_node && active_node.split('-').first == "svr"
      @temp[:selected_server] ||= MiqServer.find(@sb[:selected_server_id])  # Reread the server record
      if @sb[:selected_server_id] == @sb[:my_server_id]
        if @sb[:active_tab] == "diagnostics_evm_log"
          @log = $log.contents(120,1000)
          add_flash(_("Logs for this CFME Server are not available for viewing"), :warning) if @log.blank?
          @msg_title = "CFME"
          @refresh_action = "refresh_log"
          @download_action = "fetch_log"
        elsif @sb[:active_tab] == "diagnostics_audit_log"
          @log = $audit_log.contents(nil,1000)
          add_flash(_("Logs for this CFME Server are not available for viewing"), :warning)  if @log.blank?
          @msg_title = "Audit"
          @refresh_action = "refresh_audit_log"
          @download_action = "fetch_audit_log"
        elsif @sb[:active_tab] == "diagnostics_production_log"
          @log = $rails_log.contents(nil,1000)
          add_flash(_("Logs for this CFME Server are not available for viewing"), :warning)  if @log.blank?
          @msg_title = @sb[:rails_log]
          @refresh_action = "refresh_production_log"
          @download_action = "fetch_production_log"
        elsif @sb[:active_tab] == "diagnostics_summary"
          @temp[:selected_server] = MiqServer.find(@sb[:selected_server_id])
        elsif @sb[:active_tab] == "diagnostics_workers"
          pm_get_workers
          @record = @temp[:selected_server]
        elsif @sb[:active_tab] == "diagnostics_utilization"
          diagnostics_build_perf
        elsif @sb[:active_tab] == "diagnostics_timelines"
          diagnostics_build_timeline
        else
          @record = @temp[:selected_server] = MiqServer.find(from_cid(x_node.split("-").last).to_i)
          @sb[:selected_server_id] = @temp[:selected_server].id
          @sb[:selected_typ] = "miq_server"
        end
      elsif @sb[:selected_server_id] == @sb[:my_server_id]  || @temp[:selected_server].started?
        if @sb[:active_tab] == "diagnostics_workers"
          pm_get_workers
          @record = @temp[:selected_server]
        elsif @sb[:active_tab] == "diagnostics_utilization"
          diagnostics_build_perf
        elsif @sb[:active_tab] == "diagnostics_timelines"
          diagnostics_build_timeline
        else
          @temp[:selected_server] = MiqServer.find(from_cid(x_node.split("-").last).to_i)
          @sb[:selected_server_id] = @temp[:selected_server].id
          @sb[:selected_typ] = "miq_server"
        end
      else
        if @sb[:active_tab] == "diagnostics_utilization"
          diagnostics_build_perf
        elsif @sb[:active_tab] == "diagnostics_timelines"
          diagnostics_build_timeline
        else
          @sb[:active_tab] = "diagnostics_collect_logs"       # setting it to show collect logs tab as first tab for the servers that are not started
          @record = @temp[:selected_server] = MiqServer.find(from_cid(x_node.split("-").last).to_i)
          @sb[:selected_server_id] = @temp[:selected_server].id
          @sb[:selected_typ] = "miq_server"
        end
      end
      @right_cell_text = @sb[:my_server_id] == @sb[:selected_server_id] ?
        _("%{typ} %{model} \"%{name}\" (current)") % {:typ=>"Diagnostics", :name=>"#{@temp[:selected_server].name} [#{@temp[:selected_server].id}]", :model=>ui_lookup(:model=>@temp[:selected_server].class.to_s)} :
        _("%{typ} %{model} \"%{name}\"") % {:typ=>"Diagnostics", :name=>"#{@temp[:selected_server].name} [#{@temp[:selected_server].id}]", :model=>ui_lookup(:model=>@temp[:selected_server].class.to_s)}
    end
  end

  def build_backup_schedule_options_for_select
    @backup_schedules = {}
    database_details
    miq_schedules = MiqSchedule.where(:towhat => 'DatabaseBackup', :adhoc => nil)
    miq_schedules.sort_by { |s| s.name.downcase }.each do |s|
      @backup_schedules[s.id] = s.name if s.towhat == "DatabaseBackup"
    end
  end

  def database_details
    @database = MiqDbConfig.current.options
    db_types = MiqDbConfig.get_db_types
    @database[:display_name] = db_types[@database[:name]]
  end

  def orphaned_records_get
    @sb[:orphaned_records] = MiqReportResult.orphaned_counts_by_userid
  end

  # Method to build the server tree (parent is a zone or region instance)
  def build_server_tree(parent)
    tree_kids = Array.new

    case @sb[:diag_tree_type]
    when "roles"
      session[:tree_name] = "#{parent.class.to_s.downcase}_roles_tree"
      parent.miq_servers.sort_by { |s| s.name.to_s }.each do |s|
        unless @sb[:diag_selected_id] # Set default selected record vars
          @sb[:diag_selected_model] = s.class.to_s
          @sb[:diag_selected_id] = s.id
        end
        server_node = Hash.new
        server_node[:key] = "server_#{s.id}"
        if @sb[:diag_selected_model] == "MiqServer" && s.id == @sb[:diag_selected_id]
          server_node[:select] = true
        end
        if s.status != "stopped"
          title = "#{Dictionary::gettext('MiqServer', :type=>:model, :notfound=>:titleize)}: #{s.name}(#{s.id}) PID=#{s.pid} (#{s.status})"
        else
          title = "#{Dictionary::gettext('MiqServer', :type=>:model, :notfound=>:titleize)}: #{s.name}(#{s.id}) (#{s.status})"
        end
        server_node[:icon] = "evm_server.png"
        server_node[:title] = s.started? ?
                                "<b class='cfme-bold-node'>#{title}</b>".html_safe :
                                title
        server_node[:expand] = true
        tree_kids.push(server_node)

        server_kids = Array.new
        active_role_names = s.active_role_names
        s.assigned_server_roles.sort_by { |asr| asr.server_role.description }.each do |asr|
          next if parent.is_a?(MiqRegion) && !asr.server_role.regional_role?  # Only regional roles under Region
          if asr.server_role.name != "database_owner"
            role_node = Hash.new
            role_node[:key] = "asr_#{asr.id}"
            role_node[:title] = "Role: #{asr.server_role.description}"
            server_kids.push(asr_node_props(asr, role_node))
          end
        end
        server_node[:children] = server_kids unless server_kids.empty?
      end
    when "servers"
      session[:tree_name] = "#{parent.class.to_s.downcase}_servers_tree"
      ServerRole.all.sort_by(&:description).each do |r|
        next if parent.is_a?(MiqRegion) && !r.regional_role?  # Only regional roles under Region
        next unless (parent.is_a?(Zone) && r.miq_servers.any?{ |s| s.my_zone == parent.name }) ||
                    (parent.is_a?(MiqRegion) && !r.miq_servers.empty?) # Skip if no assigned servers in this zone
        if r.name != "database_owner"
          unless @sb[:diag_selected_id] # Set default selected record vars
            @sb[:diag_selected_model] = r.class.to_s
            @sb[:diag_selected_id] = r.id
          end
          role_node = Hash.new
          role_node[:key] = "role_#{r.id}"
          if @sb[:diag_selected_model] == "ServerRole" && r.id == @sb[:diag_selected_id]
            role_node[:select] = true
          end
          status = "stopped"
          r.assigned_server_roles.find_all_by_active(true).each do |asr|            # Go thru all active assigned server roles
            if asr.miq_server.started?        # Find a started server
              if parent.is_a?(MiqRegion) ||   # it's in the region
                  (parent.is_a?(Zone) && asr.miq_server.my_zone == parent.name) # it's in the zone
                status = "active"
                break
              end
            end
          end
          role_node[:title] = "Role: #{r.description} (#{status})"
          role_node[:icon] = "role-#{r.name}.png"
          role_node[:expand] = true
          tree_kids.push(role_node)

          role_kids = Array.new
          r.assigned_server_roles.sort_by { |asr| asr.miq_server.name }.each do |asr|
            next if parent.is_a?(Zone) && asr.miq_server.my_zone != parent.name
            server_node = Hash.new
            server_node[:key] = "asr_#{asr.id}"
            server_node[:title] = "#{Dictionary::gettext('MiqServer', :type=>:model, :notfound=>:titleize)}: #{asr.miq_server.name} [#{asr.miq_server.id}]"
            role_kids.push(asr_node_props(asr, server_node))
          end
          role_node[:children] = role_kids unless role_kids.empty?
        end
      end
    end
    if @sb[:diag_selected_id]
      @record = @sb[:diag_selected_model].constantize.find(@sb[:diag_selected_id]) # Set the current record
      @temp[:rec_status] = @record.assigned_server_roles.find_by_active(true) ? "active" : "stopped" if @record.class == ServerRole
    end
    return tree_kids
  end

  # Add assigned_server_role node properties to passed in node hash
  def asr_node_props(asr, node)
    if @sb[:diag_selected_model] == "AssignedServerRole" && asr.id == @sb[:diag_selected_id]
      node[:select] = true
    end

    if asr.master_supported?
      priority = case asr.priority
      when 1
        "primary, "
      when 2
        "secondary, "
      else
        ""
      end
    end

    node[:addClass] = "dynatree-title"
    if asr.active? && asr.miq_server.started?
      node[:icon] = "on.png"
      node[:title] += " (#{priority}active, PID=#{asr.miq_server.pid})"
    else
      if asr.miq_server.started?
        node[:icon] = "suspended.png"
        node[:title] += " (#{priority}available, PID=#{asr.miq_server.pid})"
      else
        node[:icon] = "off.png"
        node[:title] += " (#{priority}unavailable)"
      end
      node[:addClass] = "cfme-red-node" if asr.priority == 1
    end
    node[:addClass] = "cfme-bold-node" if asr.priority == 1
    if x_node != "root" && asr.server_role.regional_role? # Dim regional roles
      node[:addClass] ="cfme-opacity-node"
    end
    return node
  end

  # Get information for a node
  def diagnostics_get_info(nodetype)
    @in_a_form = false
    node = nodetype.downcase.split("-").first
    case node
    when "root"
      @sb[:diag_tree_type] ||= "roles"
      @sb[:diag_selected_id] = nil
      diagnostics_set_form_vars
    when "z"
      @sb[:diag_tree_type] ||= "roles"
      @sb[:diag_selected_id] = nil
      diagnostics_set_form_vars
    when "svr"
      @temp[:selected_server] = MiqServer.find(from_cid(nodetype.downcase.split("-").last))
      @sb[:selected_server_id] = @temp[:selected_server].id
      diagnostics_set_form_vars
    end
  end

  def diagnostics_build_tree
    TreeBuilderOpsDiagnostics.new("diagnostics_tree", "diagnostics", @sb)
  end

  def build_supported_depots_for_select
    @supported_depots_for_select = FileDepot.supported_depots.values.sort
  end
end
