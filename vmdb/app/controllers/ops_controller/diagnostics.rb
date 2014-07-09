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
      add_flash(I18n.t("flash.error_during", :task=>"Appliance restart") << bang.message, :error)
    else
      audit = {:event=>"restart_server", :message=>"Server '#{svr.name}' restarted", :target_id=>svr.id, :target_class=>"MiqServer", :userid => session[:userid]}
      AuditEvent.success(audit)
      add_flash(I18n.t("flash.ops.diagnostics.appliance_restarted"))
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
    #   add_flash(I18n.t("flash.ops.diagnostics.error_during_worker_restart", :wtype=>wtype) << bang.message, :error)
    # else
    #   audit = {:event=>"restart_workers", :message=>"#{wtype} Workers on Server '#{svr.name}' restarted", :target_id=>svr.id, :target_class=>"MiqServer", :userid => session[:userid]}
    #   AuditEvent.success(audit)
    #   add_flash(I18n.t("flash.ops.diagnostics.workers_restarted", :wtype=>wtype))
    # end
    when "ems_vimbroker"
      pm_reset_broker
    else
      begin
        svr = MiqServer.find(@sb[:selected_server_id])
        worker.restart
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"workers restart") << bang.message, :error)
      else
        audit = {:event=>"restart_workers", :message=>"Worker on Server '#{svr.name}' restarted", :target_id=>svr.id, :target_class=>"MiqWorker", :userid => session[:userid]}
        AuditEvent.success(audit)
        add_flash(I18n.t("flash.ops.diagnostics.worker_1_restarted", :wtype=>wtype))
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
      add_flash(I18n.t("flash.ops.diagnostics.edit_log_depot_cancelled"))
      @record = nil
      diagnostics_set_form_vars
      replace_right_cell(x_node)
    when "save"
      pfx = @sb[:active_tab] == "diagnostics_collect_logs" ? "logdepot" : "dbbackup"
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("#{pfx}_edit__#{id}","replace_cell__explorer")
      validate_uri_settings if @edit[:protocol].present?
      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          page << "miqSparkle(false);"
        end
        return
      end

      begin
        if @edit[:protocol].blank?
          @record.log_file_depot.destroy
        else
          new_uri = @edit[:new][:uri_prefix] + "://" + @edit[:new][:uri].to_s
          type    = Object.const_get(@edit[:protocols_hash].key(@edit[:protocol]))
          depot   = (@record.log_file_depot if @record.log_file_depot.kind_of?(type)) || @record.build_log_file_depot(:type => type.to_s)
          unless type.to_s == "FileDepotRedhatDropbox"
            depot.uri  = new_uri
            depot.name = @edit[:new][:depot_name]
          end
          depot.save
          depot.update_authentication(:default => {:userid => @edit[:new][:log_userid], :password => @edit[:new][:log_password]}) if type.try(:requires_credentials?)
          @record.save
        end
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"Save") << bang.message, :error)
        @changed = true
        render :update do |page|                    # Use RJS to update the display
          page.replace_html("diagnostics_collect_logs", :partial=>"layouts/edit_log_depot_settings")
        end
      else
        add_flash(I18n.t("flash.ops.diagnostics.log_depot_saved"))
        @edit = nil
        @record = nil
        diagnostics_set_form_vars
        replace_right_cell(x_node)
      end
    when "validate"
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("logdepot_edit__#{id}","replace_cell__explorer")
      settings = @edit[:new].dup
      settings[:uri] = @edit[:new][:uri_prefix] + "://" + @edit[:new][:uri]
      begin
        LogFile.verify_log_depot_settings(settings)
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"Validate") << bang.message, :error)
      else
        add_flash(I18n.t("flash.ops.diagnostics.log_depot_validated"))
      end
      @changed = (@edit[:new] != @edit[:current])
      render :update do |page|                    # Use RJS to update the display
        #page.replace_html(tab_div, :partial=>"layouts/edit_log_depot_settings")
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    when "reset", nil # Reset or first time in
      log_depot_build_edit_screen
      if params[:button] == "reset"
        #diagnostics
        add_flash(I18n.t("flash.edit.reset"), :warning)
      end
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
    add_flash(I18n.t("flash.evm_log_unavailable"), :warning)  if @log.blank?
    render :update do |page|                    # Use JS to update the display
      page.replace_html("diagnostics_evm_log", :partial=>"diagnostics_evm_log_tab")
      page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
    end
  end

  def refresh_audit_log
    assert_privileges("refresh_audit_log")
    @log = $audit_log.contents(nil,1000)
    @temp[:selected_server] = MiqServer.find(from_cid(x_node.split("-").last).to_i)
    add_flash(I18n.t("flash.evm_log_unavailable"), :warning)  if @log.blank?
    render :update do |page|                    # Use JS to update the display
      page.replace_html("diagnostics_audit_log", :partial=>"diagnostics_audit_log_tab")
      page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
    end
  end

  def refresh_production_log
    assert_privileges("refresh_production_log")
    @log = $rails_log.contents(nil,1000)
    @temp[:selected_server] = MiqServer.find(from_cid(x_node.split("-").last).to_i)
    add_flash(I18n.t("flash.evm_log_unavailable"), :warning)  if @log.blank?
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
      add_flash(I18n.t("flash.ops.diagnostics.end_date_error"),:error)
    else
      # converting string to time, and then converting into user selected timezone
      from =  "#{@edit[:new][:start_date]} #{@edit[:new][:start_hour]}:#{@edit[:new][:start_min]}:00".to_time.in_time_zone(@edit[:new][:timezone])
      to =  "#{@edit[:new][:end_date]} #{@edit[:new][:end_hour]}:#{@edit[:new][:end_min]}:00".to_time.in_time_zone(@edit[:new][:timezone])
      selected_zone = Zone.find_by_id(from_cid(x_node.split('-').last))
      begin
        Metric::Capture.perf_capture_gap_queue(from, to, selected_zone)
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"C & U Gap Collection") << bang.message, :error)  # Push msg and error flag
      else
        @edit[:new][:start_date] = @edit[:new][:end_date] = ""
        add_flash(I18n.t("flash.ops.diagnostics.task_initiated", :task=>"C & U Gap Collection"))
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
      add_flash(I18n.t("flash.error_during", :task=>"Reset/synchronization process") << bang.message, :error)
    else
      add_flash(I18n.t("flash.ops.diagnostics.task_initiated", :task=>"Reset/synchronization process"))
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
    return unless load_edit("dbbackup_edit__new","replace_cell__explorer")
    @edit[:selected_backup_schedule] = params[:backup_schedule] if params[:backup_schedule]
    schedule = MiqSchedule.find_by_id(@edit[:selected_backup_schedule]) if @edit[:selected_backup_schedule] && @edit[:selected_backup_schedule] != ""
    settings = schedule ? schedule.depot_hash : nil
    @prev_uri_prefix = @edit[:new][:uri_prefix]
    @edit[:protocol] = params[:log_protocol] if params[:log_protocol]
    @edit[:new][:uri_prefix] = @edit[:protocols_hash].invert[params[:log_protocol]] if params[:log_protocol]
    if settings && !settings.blank? && @prev_backup_schedule != @edit[:selected_backup_schedule]
      log_depot_get_form_vars_from_settings(settings)
      @edit[:protocol] = @edit[:new][:uri_prefix]
    else
      log_depot_get_form_vars
    end
    log_depot_set_verify_status
    render :update do |page|                    # Use RJS to update the display
      page.replace("flash_msg_divdatabase", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"database"})
      page.replace("form_filter_div",:partial=>"layouts/edit_log_depot_settings", :locals=>{:action=>"db_backup_form_field_changed", :validate_url=>"log_depot_validate",:div_num=>"validate" }) if @prev_uri_prefix != @edit[:new][:uri_prefix] ||  params[:backup_schedule]
      if (@edit[:selected_backup_schedule] == "" || @edit[:selected_backup_schedule].nil?) && (@edit[:new][:uri_prefix] == "" || @edit[:new][:uri_prefix].blank?)
        page << "$('submit_on').hide()";
        page << "$('submit_off').show()";
      else
        page << "$('submit_on').show()";
        page << "$('submit_off').hide()";
      end
      if @edit[:log_verify_status] != session[:log_depot_log_verify_status]
        session[:log_depot_log_verify_status] = @edit[:log_verify_status]
        if @edit[:log_verify_status]
          page << "miqValidateButtons('show', 'log_');"
        else
          page << "miqValidateButtons('hide', 'log_');"
        end
      end
      page << "miqSparkle(false);"
    end
  end

  def validate_uri_settings
    if @edit[:new][:uri_prefix].blank?
      add_flash(I18n.t("flash.edit.field_required", :field=>"Type"), :error)
    elsif @edit[:new][:uri_prefix] == "nfs" && @edit[:new][:uri].blank?
      add_flash(I18n.t("flash.edit.field_required", :field=>"URI"), :error)
    elsif @edit[:new][:requires_credentials]
      if @edit[:new][:uri].blank?
        add_flash(I18n.t("flash.edit.field_required", :field=>"URI"), :error)
      elsif @edit[:new][:log_userid].blank?
        add_flash(I18n.t("flash.edit.field_required", :field=>"Username"), :error)
      elsif @edit[:new][:log_password].blank?
        add_flash(I18n.t("flash.edit.field_required", :field=>"Password"), :error)
      elsif @edit[:new][:log_password] != @edit[:new][:log_verify]
        add_flash(I18n.t("flash.edit.passwords_mismatch"), :error)
      end
    end
  end

  def db_backup
    return unless load_edit("dbbackup_edit__new","replace_cell__explorer")
    @schedule = @edit && @edit[:sched_id] ? MiqSchedule.find_by_id(@edit[:sched_id]) : MiqSchedule.new(:userid=>session[:userid])
    @schedule.sched_action = {:method=>"db_backup"}
    @schedule.adhoc = true
    validate_uri_settings
    if @flash_array
      render :update do |page|
        page.replace("flash_msg_divvalidate", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"validate"})
        page << "miqSparkle(false);"
      end
      return
    end
    uri = @edit[:new][:uri_prefix] + "://" + @edit[:new][:uri]
    settings = {:uri => uri, :username => @edit[:new][:log_userid], :password => @edit[:new][:log_password] }
    #only verify_depot_hash if anything has changed in depot settings
    if @edit[:new][:uri_prefix] != @edit[:current][:uri_prefix] || @edit[:new][:uri] != @edit[:current][:uri] ||
        @edit[:new][:log_userid] != @edit[:current][:log_userid] || @edit[:new][:log_password] != @edit[:current][:log_password]
      @schedule.depot_hash=(settings) if MiqSchedule.verify_depot_hash(settings)
    end
    schedule_set_record_vars(@schedule)
    schedule_validate?(@schedule)
    if @schedule.valid? && !flash_errors? && @schedule.save
      @schedule.run_adhoc_db_backup
      add_flash(I18n.t("flash.ops.diagnostics.task_initiated", :task=>"Database Backup"))
      diagnostics_set_form_vars
      render :update do |page|                    # Use RJS to update the display
        page.replace("flash_msg_divdatabase", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"database"})
        #page.replace("form_filter_div",:partial=>"layouts/edit_log_depot_settings", :locals=>{:action=>"db_backup_form_field_changed", :validate_url=>"db_backup"})
        page.replace_html("diagnostics_database", :partial=>"diagnostics_database_tab")
        page << "miqSparkle(false);"
      end
    else
      @schedule.errors.each do |field,msg|
        add_flash("#{field.to_s.capitalize} #{msg}", :error)
      end
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      render :update do |page|                    # Use RJS to update the display
        page.replace("flash_msg_divdatabase", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"database"})
        page << "miqSparkle(false);"
      end
    end
  end

  def db_gc_collection
    return unless load_edit("dbbackup_edit__new","replace_cell__explorer")
    begin
      MiqSchedule.run_adhoc_db_gc(:userid => session[:userid])
    rescue StandardError => bang
      add_flash(I18n.t("flash.error_during", :task=>"Database Garbage Collection") << bang.message, :error)
    else
      add_flash(I18n.t("flash.ops.diagnostics.task_initiated", :task=>"Database Garbage Collection"))
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
      add_flash(I18n.t("flash.ops.diagnostics.error_during_orphaned_record_delete", :userid=>params[:userid]) << bang.message, :error)
      render :update do |page|                    # Use RJS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page << "miqSparkle(false);"
      end
    else
      audit = {:event=>"orphaned_record_delete", :message=>"Orphaned Records deleted for userid [#{params[:userid]}]", :target_id=>params[:userid], :target_class=>"MiqReport", :userid => session[:userid]}
      AuditEvent.success(audit)
      add_flash(I18n.t("flash.ops.diagnostics.orphaned_records_deleted", :userid=>params[:userid]))
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
        page << "if($('center_buttons_div')) $('center_buttons_div').show();"
      else
        page << "dhxLayoutB.cells('a').collapse();"
        page << "if($('center_buttons_div')) $('center_buttons_div').hide();"
      end
      page << "dhxLayoutB.cells('a').collapse();" if @sb[:center_tb_filename] == "blank_view_tb"
    end
  end

  def log_depot_field_changed
    id = params[:id] ? params[:id] : "new"
    if x_active_tree == :diagnostics_tree
      if @sb[:active_tab] == "diagnostics_database"
        #coming from diagnostics/database tab
        pfx = "dbbackup"
        flash_div_num = "validate"
        @schedule = @edit && @edit[:sched_id] ? MiqSchedule.find_by_id(@edit[:sched_id]) : MiqSchedule.new(:userid=>session[:userid])
      else
        @record = MiqServer.find_by_id(@sb[:selected_server_id])
        pfx = "logdepot"
        flash_div_num = ""
      end
    else
      #add/edit dbbackup schedule
      pfx = "schedule"
      flash_div_num = "validate"
      #need to set this for edit_log_depot_settings view
      @schedule = session[:edit] && session[:edit][:sched_id] ? MiqSchedule.find_by_id(session[:edit][:sched_id]) : MiqSchedule.new(:userid=>session[:userid])
    end
    return unless load_edit("#{pfx}_edit__#{id}","replace_cell__explorer")
    log_depot_get_form_vars
    log_depot_set_verify_status
    changed = (@edit[:new] != @edit[:current])
    required_fields = @edit[:new].values_at(:uri, :log_userid, :log_password, :log_verify)
    render :update do |page|                    # Use JS to update the display
      session[:changed] = changed
      page.replace("form_filter_div",:partial=>"layouts/edit_log_depot_settings", :locals=>{:div_num=>flash_div_num}) if @prev_protocol != @edit[:protocol]
      if @sb[:active_tab] == "diagnostics_database"
        if changed && @edit[:new][:requires_credentials] &&
            (@edit[:new][:log_password] == @edit[:new][:log_verify]) &&
            (required_fields.all?(&:blank?) || required_fields.all?(&:present?))
          page << "$('submit_on').show()";
          page << "$('submit_off').hide()";
          page << "miqButtons('show');"
        else
          if changed
            page << "$('submit_on').show()";
            page << "$('submit_off').hide()";
          else
            page << "$('submit_on').hide()";
            page << "$('submit_off').show()";
          end
          page << javascript_for_miq_button_visibility(changed && @edit[:new][:uri_prefix] == "nfs")
        end
      else
        if changed && @edit[:new][:requires_credentials] &&
            (@edit[:new][:log_password] == @edit[:new][:log_verify]) &&
            (required_fields.all?(&:blank?) || required_fields.all?(&:present?))
          page << "miqButtons('show');"
        else
          page << javascript_for_miq_button_visibility(changed && !@edit[:new][:requires_credentials])
        end
      end
      if @edit[:log_verify_status] != session[:log_depot_log_verify_status]
        session[:log_depot_log_verify_status] = @edit[:log_verify_status]
        if @edit[:log_verify_status]
          page << "miqValidateButtons('show', 'log_');"
        else
          page << "miqValidateButtons('hide', 'log_');"
        end
      end
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

  def log_depot_get_form_vars_from_settings(settings)
    protocol, path = settings[:uri].to_s.split('://')
    @edit[:new][:uri_prefix]   = protocol
    @edit[:new][:uri]          = path
    @edit[:new][:log_userid]   = settings[:username]
    @edit[:new][:log_password] = settings[:password]
    @edit[:new][:log_verify]   = settings[:password]
  end

  def log_depot_get_form_vars
    @record = @sb[:selected_typ].classify.constantize.find_by_id(@sb[:selected_server_id])
    @prev_uri_prefix = @edit[:new][:uri_prefix]
    @prev_protocol   = @edit[:protocol]
    @edit[:protocol] = params[:log_protocol] if params[:log_protocol] # @edit[:protocol] holds the current value of the selector so that it is not reset when _field_changed is called

    if @sb[:active_tab] == "diagnostics_collect_logs"
      klass = @edit[:protocol].present? ? Object.const_get(@edit[:protocols_hash].key(@edit[:protocol])) : nil
      @edit[:new][:requires_credentials] = klass.try(:requires_credentials?)
      @edit[:new][:uri_prefix] = klass.try(:uri_prefix)
    else
      @edit[:new][:uri_prefix] = @edit[:protocols_hash].invert[params[:log_protocol]] if params[:log_protocol]
      @edit[:new][:requires_credentials] = @edit[:new][:uri_prefix] != "nfs"
    end

    @edit[:new][:depot_name] = params[:depot_name] if params[:depot_name]
    if @edit[:new][:uri_prefix].in?([nil, "nfs"]) || params[:backup_schedule] == ""
      @edit[:new][:uri]          = params[:log_protocol] == "" ? nil : params[:uri]
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

  def log_depot_build_edit_screen
    @edit = Hash.new
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:protocols_hash] = FileDepot.supported_depots
    #have to create array to add <choose> on the top in the form
    @edit[:protocols_arr] = @edit[:protocols_hash].values
    @edit[:key] = "logdepot_edit__#{@record.id || "new"}"
    log_depot = @record.log_file_depot.try(:depot_hash)
    log_depot_get_form_vars_from_settings(log_depot) if log_depot.present?
    klass                              = @record.log_file_depot.try(:class)
    @edit[:protocol]                   = klass.try(:const_get, "DISPLAY_NAME")
    @edit[:new][:depot_name]           = @record.log_file_depot.try(:name)
    @edit[:new][:requires_credentials] = klass.try(:requires_credentials?)

    @edit[:current] = copy_hash(@edit[:new])
    @in_a_form = true
    log_depot_set_verify_status
    session[:changed] = (@edit[:new] != @edit[:current])
  end

  def pm_reset_broker
    @lastaction = "reset_broker"
    ems = ExtManagementSystem.all
    ems.each do |ms|
      begin
        ms.reset_vim_cache_queue              # Run the task
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"Clear Connection Broker cache") << bang.message, :error)
      else
        audit = {:event=>"reset_broker", :message=>"Connection Broker cache cleared successfully", :target_id=>ms.id, :target_class=>"ExtManagementSystem", :userid => session[:userid]}
        AuditEvent.success(audit)
        add_flash(I18n.t("flash.ops.diagnostics.connection_broker_cache_cleared"))
      end
    end
    pm_get_workers
  end

  # Collect the current logs from the selected zone or server
  def logs_collect(options={})
    obj, id  = x_node.split("-")
    assert_privileges("#{obj == "z" ? "zone_" : ""}collect_logs")
    klass    = obj == "svr" ? MiqServer : Zone
    instance = @temp[:selected_server] = klass.find(from_cid(id).to_i)
    if !instance.active?
      add_flash(I18n.t("flash.ops.diagnostics.log_collection_error_no_server_started"), :error)
    elsif instance.log_collection_active_recently?
      add_flash(I18n.t("flash.ops.diagnostics.log_collection_error_already_in_progress"), :error)
    else
      begin
        instance.synchronize_logs(session[:userid], options)
      rescue StandardError => bang
        add_flash(I18n.t("flash.ops.diagnostics.log_collection_error") << bang.message, :error)
      else
        add_flash(I18n.t("flash.ops.diagnostics.log_collection_initiated", :object_type => klass.name, :name => instance.display_name))
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
      add_flash(I18n.t("flash.ops.diagnostics.task_not_allowed", :task=>"Start"), :error)
    else
      asr = AssignedServerRole.find(@sb[:diag_selected_id])
      begin
        asr.activate_in_role_scope
      rescue StandardError => bang
        add_flash(bang, :error)
      else
        add_flash(I18n.t("flash.ops.diagnostics.task_initiated", :task=>"Start"))
      end
    end
    refresh_screen
  end

  def role_suspend
    assert_privileges("role_suspend")
    if @sb[:diag_selected_model] != "AssignedServerRole"
      add_flash(I18n.t("flash.ops.diagnostics.task_not_allowed", :task=>"Suspend"), :error)
    else
      asr = AssignedServerRole.find(@sb[:diag_selected_id])
      begin
        asr.deactivate_in_role_scope
      rescue StandardError => bang
        add_flash(bang, :error)
      else
        add_flash(I18n.t("flash.ops.diagnostics.task_initiated", :task=>"Suspend"), :error)
      end
    end
    refresh_screen
  end

  # Delete all selected server
  def delete_server
    assert_privileges("delete_server")
    servers = Array.new
    if @sb[:diag_selected_id].nil?
      add_flash(I18n.t("flash.record.no_longer_exists", :model=>ui_lookup(:table=>"evm_server")), :error)
    else
      servers.push(@sb[:diag_selected_id])
    end
    process_servers(servers, "destroy") if ! servers.empty?
    add_flash(I18n.t("flash.record.deleted_for_1_record", :model=>ui_lookup(:table=>"evm_server"))) if @flash_array == nil
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
        add_flash(I18n.t("flash.record.error_during_task",
                        :model=>ui_lookup(:model=>"MiqServer"), :name=>svr_name, :task=>task) << bang.message,
                  :error)
      else
        if task == "destroy"
          AuditEvent.success(audit)
          add_flash(I18n.t("flash.record.deleted", :model=>ui_lookup(:model=>"MiqServer"), :name=>"#{svr_name} [#{svr.id}]"))
        else
          add_flash(I18n.t("flash.record.task_started", :model=>ui_lookup(:model=>"MiqServer"), :name=>"#{svr_name} [#{svr.id}]", :task=>task))
        end
      end
    end
  end

  def promote_server
    assert_privileges("promote_server")
    if @sb[:diag_selected_model] != "AssignedServerRole"
      add_flash(I18n.t("flash.ops.diagnostics.setting_priority_not_allowed"), :error)
    else
      asr = AssignedServerRole.find(@sb[:diag_selected_id])
      begin
        asr.set_priority(asr.priority - 1)
      rescue StandardError => bang
        add_flash(bang, :error)
      else
        priority = asr.priority == 1 ? "primary" : (asr.priority == 2 ? "secondary" : "normal")
        add_flash(I18n.t("flash.ops.diagnostics.priority_set_for_server",
            :name=>asr.miq_server.name, :priority=>priority, :role_description=>asr.server_role.description))
      end
    end
    refresh_screen
  end

  def demote_server
    assert_privileges("demote_server")
    if @sb[:diag_selected_model] != "AssignedServerRole"
      add_flash(I18n.t("flash.ops.diagnostics.setting_priority_not_allowed"), :error)
    else
      asr = AssignedServerRole.find(@sb[:diag_selected_id])
      begin
        asr.set_priority(asr.priority + 1)
      rescue StandardError => bang
        add_flash(bang, :error)
      else
        priority = asr.priority == 1 ? "primary" : (asr.priority == 2 ? "secondary" : "normal")
        add_flash(I18n.t("flash.ops.diagnostics.priority_set_for_server",
            :name=>asr.miq_server.name, :priority=>priority, :role_description=>asr.server_role.description))
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
        page << "if($('center_buttons_div')) $('center_buttons_div').show();"
      else
        page << "dhxLayoutB.cells('a').collapse();"
        page << "if($('center_buttons_div')) $('center_buttons_div').hide();"
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
        I18n.t("cell_header.type_of_model_record_current",:typ=>"Diagnostics",:name=>@temp[:selected_server].description,:model=>ui_lookup(:model=>@temp[:selected_server].class.to_s)) :
        I18n.t("cell_header.type_of_model_record",:typ=>"Diagnostics",:name=>@temp[:selected_server].description,:model=>ui_lookup(:model=>@temp[:selected_server].class.to_s))
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
        @edit = Hash.new
        @edit[:new] = Hash.new
        @edit[:current] = Hash.new
        @edit[:key] = "dbbackup_edit__new"
        @edit[:backup_schedules] = Hash.new
        @database = MiqDbConfig.current.options
        db_types = MiqDbConfig.get_db_types
        @database[:display_name] = db_types[@database[:name]]
        MiqSchedule.all(:conditions=>"towhat = 'DatabaseBackup' And adhoc is NULL").sort{|a,b| a.name.downcase <=> b.name.downcase}.each do |s|
          if s.towhat == "DatabaseBackup"
            @edit[:backup_schedules][s.id] = s.name
          end
        end
        @schedule = MiqSchedule.new(:userid=>session[:userid])
        @edit[:sched_id] = @schedule.id
        @edit[:new][:name] = "__adhoc_dbbackup_#{Time.now}__"
        @edit[:new][:description] = "Adhoc DB Backup at #{Time.now}"
        @edit[:new][:action] = "db_backup"
        t = Time.now + 1.day  # Default date/time to tomorrow in selected time zone
        @edit[:new][:timer_months ] = "1"
        @edit[:new][:timer_weeks ] = "1"
        @edit[:new][:timer_days] = "1"
        @edit[:new][:timer_hours] = "1"
        @edit[:new][:timer_typ] = "Once"
        @edit[:new][:start_hour] = "00"
        @edit[:new][:start_min] = "00"

        @edit[:protocols_hash] = DatabaseBackup.supported_depots
        #have to create array to add <choose> on the top in the form
        @edit[:protocols_arr] = Array.new
        @edit[:protocols_hash].each do |p|
          @edit[:protocols_arr].push(p[1])
        end
        set_log_depot_vars
        @edit[:current] = copy_hash(@edit[:new])
      elsif @sb[:active_tab] == "diagnostics_orphaned_data"
        orphaned_records_get
      elsif @sb[:active_tab] == "diagnostics_server_list"
      diagnostics_server_list
      end
      @right_cell_text = I18n.t("cell_header.type_of_model_record",:typ=>"Diagnostics",:name=>"#{MiqRegion.my_region.description} [#{MiqRegion.my_region.region}]",:model=>ui_lookup(:model=>"MiqRegion"))
    elsif active_node && active_node.split('-').first == "svr"
      @temp[:selected_server] ||= MiqServer.find(@sb[:selected_server_id])  # Reread the server record
      if @sb[:selected_server_id] == @sb[:my_server_id]
        if @sb[:active_tab] == "diagnostics_evm_log"
          @log = $log.contents(120,1000)
          add_flash(I18n.t("flash.evm_log_unavailable"), :warning) if @log.blank?
          @msg_title = "CFME"
          @refresh_action = "refresh_log"
          @download_action = "fetch_log"
        elsif @sb[:active_tab] == "diagnostics_audit_log"
          @log = $audit_log.contents(nil,1000)
          add_flash(I18n.t("flash.evm_log_unavailable"), :warning)  if @log.blank?
          @msg_title = "Audit"
          @refresh_action = "refresh_audit_log"
          @download_action = "fetch_audit_log"
        elsif @sb[:active_tab] == "diagnostics_production_log"
          @log = $rails_log.contents(nil,1000)
          add_flash(I18n.t("flash.evm_log_unavailable"), :warning)  if @log.blank?
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
        I18n.t("cell_header.type_of_model_record_current",:typ=>"Diagnostics",:name=>"#{@temp[:selected_server].name} [#{@temp[:selected_server].id.to_s}]",:model=>ui_lookup(:model=>@temp[:selected_server].class.to_s)) :
        I18n.t("cell_header.type_of_model_record",:typ=>"Diagnostics",:name=>"#{@temp[:selected_server].name} [#{@temp[:selected_server].id.to_s}]",:model=>ui_lookup(:model=>@temp[:selected_server].class.to_s))
    end
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
      parent.miq_servers.sort{|a,b| a.name.to_s <=> b.name.to_s}.each do |s|
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
        s.assigned_server_roles.sort{|a,b| a.server_role.description <=> b.server_role.description}.each do |asr|
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
      ServerRole.all.sort{|a,b| a.description <=> b.description}.each do |r|
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
          r.assigned_server_roles.sort{|a,b| a.miq_server.name <=> b.miq_server.name}.each do |asr|
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

end
