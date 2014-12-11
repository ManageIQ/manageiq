module OpsController::Settings::Schedules
  extend ActiveSupport::Concern

  # Show the main Schedules list view
  def schedules_list
    schedule_build_list
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page]
      render :update do |page|
        page.replace("gtl_div", :partial=>"layouts/x_gtl", :locals=>{:action_url=>"schedules_list"})
        page.replace_html("paging_div", :partial=>"layouts/x_pagingcontrols")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  def schedule_show
    @display = "main"
    return if record_no_longer_exists?(@selected_schedule)

    # Get configured tz, else use user's tz
    @timezone = @selected_schedule.run_at && @selected_schedule.run_at[:tz] ?
                  @selected_schedule.run_at[:tz] : session[:user_tz]

    if @selected_schedule.filter.is_a?(MiqExpression)
      @exp_table = exp_build_table(@selected_schedule.filter.exp)
    end
  end

  def schedule_add
    assert_privileges("schedule_add")
    @_params[:typ] = "new"
    schedule_edit
  end

  def schedule_edit
    assert_privileges("schedule_edit")
    case params[:button]
    when "cancel"
      @schedule = MiqSchedule.find_by_id(session[:edit][:sched_id]) if session[:edit] && session[:edit][:sched_id]
      if !@schedule || @schedule.id.blank?
        add_flash(_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"MiqSchedule"))
      else
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"MiqSchedule"), :name=>@schedule.name})
      end
      get_node_info(x_node)
      @schedule = nil
      @edit = session[:edit] = nil  # clean out the saved info
      replace_right_cell(@nodetype)
    when "save", "add"
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("schedule_edit__#{id}","replace_cell__explorer")
      @schedule = @edit && @edit[:sched_id] ? MiqSchedule.find_by_id(@edit[:sched_id]) : MiqSchedule.new(:userid=>session[:userid])
      if @edit[:new][:action] == "db_backup"
        @schedule.sched_action = {:method=>"db_backup"}
        if @edit[:new][:uri_prefix].blank?
          add_flash(_("%s is required") % "Type", :error)
        elsif @edit[:new][:uri_prefix] == "nfs" && @edit[:new][:uri].blank?
          add_flash(_("%s is required") % "URI", :error)
        elsif @edit[:new][:uri_prefix] == "smb" || @edit[:new][:uri_prefix] == "ftp"
          if @edit[:new][:uri].blank?
            add_flash(_("%s is required") % "URI", :error)
          elsif @edit[:new][:log_userid].blank?
            add_flash(_("%s is required") % "Username", :error)
          elsif @edit[:new][:log_password].blank?
            add_flash(_("%s is required") % "Password", :error)
          end
        end
        if @flash_array
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
          return
        end
        uri = @edit[:new][:uri_prefix] + "://" + @edit[:new][:uri]
        settings_new = {:uri      => uri,
                        :username => @edit[:new][:log_userid],
                        :password => @edit[:new][:log_password],
                        :name     => @edit[:new][:depot_name]}
        settings_current = {:uri      => @edit[:current][:uri],
                            :username => @edit[:current][:log_userid],
                            :password => @edit[:current][:log_password],
                            :name     => @edit[:current][:depot_name]}

        # only verify_depot_hash if anything has changed in depot settings
        if settings_new != settings_current
          if MiqSchedule.verify_depot_hash(settings_new)
            @schedule.depot_hash = settings_new
          else
            add_flash(_("Failed to add depot. See logs for detail."), :error)
          end
        end
      end
      schedule_set_record_vars(@schedule)
      schedule_validate?(@schedule)
      if @schedule.valid? && !flash_errors? && @schedule.save
        AuditEvent.success(build_saved_audit(@schedule, params[:button] == "add"))
        add_flash(_("%{model} \"%{name}\" was saved") % {:model=>ui_lookup(:model=>"MiqSchedule"), :name=>@schedule.name})
        @edit = session[:edit] = nil  # clean out the saved info
        if params[:button] == "add"
          self.x_node  = "xx-msc"  # reset node to show list
          schedules_list
          settings_get_info("st")
        else          #set selected schedule
          @selected_schedule = MiqSchedule.find(@schedule.id)
          get_node_info(x_node)
        end
        replace_right_cell("root",[:settings])
      else
        @schedule.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        @changed = session[:changed] = (@edit[:new] != @edit[:current])
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      end
    when "reset", nil # Reset or first time in
      obj = find_checked_items
      obj[0] = params[:id] if obj.blank? && params[:id]
      @schedule = params[:typ] == "new" ? MiqSchedule.new(:userid=>session[:userid])  : MiqSchedule.find(obj[0])          # Get existing or new record
      schedule_set_form_vars
      schedule_build_edit_screen
      @in_a_form = true
      session[:changed] = false
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("se")
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def schedule_form_field_changed
    return unless load_edit("schedule_edit__#{params[:id]}","replace_cell__explorer")
    schedule_get_form_vars
    render :update do |page|                    # Use JS to update the display
      if params[:action_typ]
        @edit[:new][:action] = params[:action_typ]
        if params[:action_typ] == "db_backup"
          page.replace("form_filter_div",
                       :partial => "layouts/edit_log_depot_settings",
                       :locals  => {:action       => "log_depot_field_changed",
                                    :validate_url => "log_depot_validate"})
        else
          @edit[:new][:filter] = "all"
          page.replace("form_filter_div", :partial=>"schedule_form_filter")
        end
      end
      if params[:filter_typ]
        @edit[:new][:filter_value] = nil        # Clear filter value if filter type changed
        page.replace("form_filter_div", :partial=>"schedule_form_filter")
      end

      javascript_for_timer_type(params[:timer_typ]).each { |js| page << js }

      if params[:time_zone]
        page << "miq_cal_dateFrom = new Date(#{(Time.now - 1.month).in_time_zone(@edit[:tz]).strftime("%Y,%m,%d")});"
        page << "miqBuildCalendar();"
        page << "$('miq_date_1').value = '#{@edit[:new][:start_date]}';"
        page << "$('start_hour').value = '#{@edit[:new][:start_hour].to_i}';"
        page << "$('start_min').value = '#{@edit[:new][:start_min].to_i}';"
        page.replace_html("tz_span", @timezone_abbr)
      end
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

    # Delete all selected or single displayed action(s)
  def schedule_delete
    assert_privileges("schedule_delete")
    schedules = Array.new
    if !params[:id] # showing a list
      schedules = find_checked_items
      if schedules.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:tables=>"miq_schedule"), :task=>"deletion"}, :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
      process_schedules(schedules, "destroy") unless schedules.empty?
      schedule_build_list
      settings_get_info("st")
      replace_right_cell("root",[:settings])
    else # showing 1 schedule, delete it
      if params[:id] == nil || MiqSchedule.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:table=>"miq_schedule"), :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      else
        schedules.push(params[:id])
      end
      process_schedules(schedules, "destroy") if ! schedules.empty?
      self.x_node = "xx-msc"
      get_node_info(x_node)
      replace_right_cell(x_node,[:settings])
    end
  end

  def schedule_toggle(enable)
    present_action = enable ? 'enable' : 'disable'
    past_action = present_action + 'd'

    schedules = find_checked_items
    if schedules.empty?
      add_flash(I18n.t("flash.no_records_selected_to_be_#{past_action}",
                    :model=>ui_lookup(:models=>"MiqSchedule")),
              :error)
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
    schedule_enable_disable(schedules, present_action)  unless schedules.empty?
    add_flash(I18n.t("flash.selected_records_were_#{past_action}",
                    :model=>ui_lookup(:models=>"MiqSchedule")),
              :info, true) if ! flash_errors?
    schedule_build_list
    settings_get_info("st")
    replace_right_cell("root")
  end

  def schedule_enable
    assert_privileges("schedule_enable")
    schedule_toggle(true)
  end

  def schedule_disable
    assert_privileges("schedule_disable")
    schedule_toggle(false)
  end

  private

  # Create the view and associated vars for the schedules list
  def schedule_build_list
    @lastaction = "schedules_list"
    @force_no_grid_xml = true
    @gtl_type = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end
    @sortcol = session[:schedule_sortcol] == nil ? 0 : session[:schedule_sortcol].to_i
    @sortdir = session[:schedule_sortdir] == nil ? "ASC" : session[:schedule_sortdir]

    #don't include db_backup records if backup not supported
    if !DatabaseBackup.backup_supported?
      @view, @pages = get_view(MiqSchedule, :conditions=>["towhat!=? And (prod_default!=? or prod_default IS NULL) And adhoc IS NULL", "DatabaseBackup","system"]) # Get the records (into a view) and the paginator
    else
      @view, @pages = get_view(MiqSchedule, :conditions=>["prod_default!=? or prod_default IS NULL And adhoc IS NULL", "system"]) # Get the records (into a view) and the paginator
    end

    @current_page = @pages[:current] if @pages != nil # save the current page number
    session[:schedule_sortcol] = @sortcol
    session[:schedule_sortdir] = @sortdir
  end

  # Validate some of the schedule fields
  def schedule_validate?(sched)
    valid = true
    if @edit[:new][:action] != "db_backup"
      if ["global","my"].include?(@edit[:new][:filter])
        if @edit[:new][:filter_value].blank?  # Check for search filter chosen
          add_flash(_("%s must be selected") % "filter", :error)
          valid = false
        end
      elsif sched.filter.exp.keys.first != "IS NOT NULL" && @edit[:new][:filter_value].blank? # Check for empty filter value
        add_flash(_("%s must be selected") % "filter value", :error)
        valid = false
      end
    end
    unless flash_errors?
      if sched.run_at[:interval][:unit] == "once" &&
          sched.run_at[:start_time].to_time.utc < Time.now.utc &&
          sched.enabled == true
        add_flash(_("Warning: This 'Run Once' timer is in the past and will never run as currently configured"), :warning)
      end
    end
    return valid
  end

  # Set form variables for edit
  def schedule_set_form_vars
    @timezone_abbr = get_timezone_abbr("server")
    @edit = Hash.new

    # Remember how this edit started
    @edit[:type] = ["copy", "new"].include?(params[:action]) ? "new" : "edit"

    # Get configured tz, default to user's tz
    @edit[:tz] = @schedule.run_at && @schedule.run_at[:tz] ? @schedule.run_at[:tz] : session[:user_tz]

    @edit[:sched_id] = @schedule.id
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "schedule_edit__#{@schedule.id || "new"}"

    @edit[:new][:name] = @schedule.name
    @edit[:new][:description] = @schedule.description
    @edit[:action_types] = [
                             ["VM Analysis","vm"],
                             ["Template Analysis","miq_template"],
                             ["Host Analysis","host"],
                             ["#{ui_lookup(:model=>'EmsCluster')} Analysis","emscluster"],
                             ["#{ui_lookup(:model=>'Storage')} Analysis","storage"]
                           ]
    @edit[:action_types].push(["VM Compliance Check","vm_check_compliance"]) if role_allows(:feature=>"vm_check_compliance")
    @edit[:action_types].push(["Host Compliance Check","host_check_compliance"]) if role_allows(:feature=>"host_check_compliance")
    @edit[:action_types].push(["Database Backup","db_backup"]) if DatabaseBackup.backup_supported?

    @edit[:new][:enabled] = @schedule.enabled == nil ? false : @schedule.enabled
    if @schedule.sched_action && @schedule.sched_action[:method] && @schedule.sched_action[:method] == "check_compliance"
      @edit[:new][:action] = @schedule.towhat.downcase + "_" + @schedule.sched_action[:method]
    elsif @schedule.sched_action && @schedule.sched_action[:method] && @schedule.sched_action[:method] == "db_backup"
      @edit[:new][:action] = @schedule.sched_action[:method]
      @edit[:protocols_hash] = DatabaseBackup.supported_depots
      #have to create array to add <choose> on the top in the form
      @edit[:protocols_arr] = Array.new
      @edit[:protocols_hash].each do |p|
        @edit[:protocols_arr].push(p[1])
      end
      set_log_depot_vars
    else
      if @schedule.towhat == nil
        @edit[:new][:action] = "vm"
      else
        @edit[:new][:action] ||= @schedule.towhat == "EmsCluster" ? "emscluster" : @schedule.towhat.underscore
      end
    end
    if @schedule.sched_action && @schedule.sched_action[:method] && @schedule.sched_action[:method] != "db_backup"
      if @schedule.miq_search                         # See if a search filter is attached
        @edit[:new][:filter] = @schedule.miq_search.search_type == "user" ? "my" : "global"
        @edit[:new][:filter_value] = @schedule.miq_search.id
      elsif @schedule.filter == nil                   # Set to All if not set
        @edit[:new][:filter] = "all"
        @edit[:new][:filter_value] = nil
      else
        key = @schedule.filter.exp.keys.first
        if key == "IS NOT NULL"                       # All
          @edit[:new][:filter] = "all"
          @edit[:new][:filter_value] = nil
        elsif key == "AND"                            # Cluster name and datacenter
          @edit[:new][:filter] = "cluster"
          @edit[:new][:filter_value] = @schedule.filter.exp[key][0]["="]["value"] + "__" + @schedule.filter.exp[key][1]["="]["value"]
        else
          case @schedule.filter.exp[key]["field"]
          when "Vm.ext_management_system-name", "MiqTemplate.ext_management_system-name"
            @edit[:new][:filter] = "ems"
          when "Vm.host-name", "MiqTemplate.host-name"
            @edit[:new][:filter] = "host"
          when "Vm-name"
            @edit[:new][:filter] = "vm"
          when "MiqTemplate-name"
            @edit[:new][:filter] = "miq_template"
          when "Storage.ext_management_system-name"
            @edit[:new][:filter] = "ems"
          when "Storage.host-name"
            @edit[:new][:filter] = "host"
          when "Storage-name"
            @edit[:new][:filter] = "storage"
          when "Host.ext_management_system-name"
            @edit[:new][:filter] = "ems"
          when "Host-name"
            @edit[:new][:filter] = "host"
          when "EmsCluster.ext_management_system-name"
            @edit[:new][:filter] = "ems"
          end
          @edit[:new][:filter_value] = @schedule.filter.exp[key]["value"]
        end
      end
    end
    set_edit_timer_from_schedule(@schedule)

    @edit[:current] = copy_hash(@edit[:new])

    session[:edit] = @edit
  end

  # Get variables from edit form
  def schedule_get_form_vars
    @schedule = @edit && @edit[:sched_id] ? MiqSchedule.find_by_id(@edit[:sched_id]) : MiqSchedule.new(:userid=>session[:userid])

    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:enabled] = (params[:enabled] == "1") if params[:enabled]
    @edit[:new][:action] = params[:action_typ] if params[:action_typ]
    if params[:action_typ] == "db_backup"
      @edit[:protocols_hash] = DatabaseBackup.supported_depots
      #have to create array to add <choose> on the top in the form
      @edit[:protocols_arr] = Array.new
      @edit[:protocols_hash].each do |p|
        @edit[:protocols_arr].push(p[1])
      end
      if params[:action_typ] == @edit[:current][:action]
        #need to delete these if action was changed and reset data
        @edit[:new].delete(:filter) if @edit[:new].has_key?(:filter)
        @edit[:new].delete(:filter_value) if @edit[:new].has_key?(:filter_value)
        set_log_depot_vars
      end
    else
      if params[:action_typ] == @edit[:current][:action]
        #need to delete these if action was changed and reset data
        @edit[:new].delete(:uri_prefix) if @edit[:new].has_key?(:uri_prefix)
        @edit[:new].delete(:uri) if @edit[:new].has_key?(:uri)
        @edit[:new].delete(:log_userid) if @edit[:new].has_key?(:log_userid)
        @edit[:new].delete(:log_password) if @edit[:new].has_key?(:log_password)
        @edit[:new].delete(:log_verify) if @edit[:new].has_key?(:log_verify)
      end
    end
    @edit[:new][:filter] = params[:filter_typ] if params[:filter_typ]
    if params[:filter_value]
      @edit[:new][:filter_value] = params[:filter_value] == "<Choose>" ? nil : params[:filter_value]
    end
    @edit[:new][:timer_typ] = params[:timer_typ] if params[:timer_typ]
    @edit[:new][:timer_months] = params[:timer_months] if params[:timer_months]
    @edit[:new][:timer_weeks] = params[:timer_weeks] if params[:timer_weeks]
    @edit[:new][:timer_days] = params[:timer_days] if params[:timer_days]
    @edit[:new][:timer_hours] = params[:timer_hours] if params[:timer_hours]
    @edit[:new][:start_date] = params[:miq_date_1] if params[:miq_date_1]
    @edit[:new][:start_hour] = params[:start_hour] if params[:start_hour]
    @edit[:new][:start_min] = params[:start_min] if params[:start_min]

    if params[:time_zone]
      @edit[:tz] = params[:time_zone]
      @timezone_abbr = Time.now.in_time_zone(@edit[:tz]).strftime("%Z")
      t = Time.now.in_time_zone(@edit[:tz]) + 1.day # Default date/time to tomorrow in selected time zone
      @edit[:new][:start_date] = "#{t.month}/#{t.day}/#{t.year}"  # Reset the start date
      @edit[:new][:start_hour] = "00" # Reset time to midnight
      @edit[:new][:start_min] = "00"
    end
  end

  def schedule_build_edit_screen
    @schedule = @edit && @edit[:sched_id] ? MiqSchedule.find_by_id(@edit[:sched_id]) : MiqSchedule.new(:userid=>session[:userid])
    @in_a_form = true

    # Build pulldown arrays
    @edit[:emss] = Array.new
    find_filtered(ExtManagementSystem, :all).sort{|a,b| a.name.downcase<=>b.name.downcase}.each{|e|@edit[:emss].push(e.name)}
    @edit[:clusters] = Hash.new
    find_filtered(EmsCluster, :all).sort{|a,b| a.name.downcase<=>b.name.downcase}.each{|c|
      @edit[:clusters][c.name + "__" + c.v_parent_datacenter] = c.v_qualified_desc
    }
    @edit[:hosts] = Array.new
    find_filtered(Host, :all).sort{|a,b| a.name.downcase<=>b.name.downcase}.each{|h|@edit[:hosts].push(h.name)}
    @edit[:vms] = Array.new
    find_filtered(Vm, :all).sort{|a,b| a.name.downcase<=>b.name.downcase}.each{|v|@edit[:vms].push(v.name)}
    @edit[:miq_templates] = Array.new
    find_filtered(MiqTemplate, :all).sort{|a,b| a.name.downcase<=>b.name.downcase}.each{|t|@edit[:miq_templates].push(t.name)}
    @edit[:datastores] = Array.new
    find_filtered(Storage, :all).sort{|a,b| a.name.downcase<=>b.name.downcase}.each{|h|@edit[:datastores].push(h.name)}

    # Build search filter pulldowns
    @edit[:filters] = Hash.new
    build_listnav_search_list("Vm")
    @edit[:filters][:vm_global] = @def_searches.delete_if{|s| s.id == 0}.collect{|s| [s.description, s.id]}
    @edit[:filters][:vm_my] = @my_searches.collect{|s| [s.description, s.id]}
    build_listnav_search_list("MiqTemplate")
    @edit[:filters][:miq_template_global] = @def_searches.delete_if{|s| s.id == 0}.collect{|s| [s.description, s.id]}
    @edit[:filters][:miq_template_my] = @my_searches.collect{|s| [s.description, s.id]}
    build_listnav_search_list("Host")
    @edit[:filters][:host_global] = @def_searches.delete_if{|s| s.id == 0}.collect{|s| [s.description, s.id]}
    @edit[:filters][:host_my] = @my_searches.collect{|s| [s.description, s.id]}
    build_listnav_search_list("EmsCluster")
    @edit[:filters][:cluster_global] = @def_searches.delete_if{|s| s.id == 0}.collect{|s| [s.description, s.id]}
    @edit[:filters][:cluster_my] = @my_searches.collect{|s| [s.description, s.id]}
    build_listnav_search_list("Storage")
    @edit[:filters][:storage_global] = @def_searches.delete_if{|s| s.id == 0}.collect{|s| [s.description, s.id]}
    @edit[:filters][:storage_my] = @my_searches.collect{|s| [s.description, s.id]}
  end

  # Set record variables to new values
  def schedule_set_record_vars(schedule)
    schedule.name = @edit[:new][:name]
    schedule.description = @edit[:new][:description]
    schedule.enabled = @edit[:new][:enabled]
    if @edit[:new][:action] == "db_backup"
      schedule.towhat = "DatabaseBackup"
    elsif @edit[:new][:action].ends_with?("check_compliance")
      schedule.towhat = @edit[:new][:action].split("_").first.capitalize
    else
      schedule.towhat = @edit[:new][:action] == "emscluster" ? "EmsCluster" : @edit[:new][:action].camelcase
    end
    if ["vm", "miq_template"].include?(@edit[:new][:action])
      schedule.sched_action = {:method=>"vm_scan"}      # Default to vm_scan method for now
    elsif @edit[:new][:action].ends_with?("check_compliance")
      schedule.sched_action = {:method=>"check_compliance"}
    elsif @edit[:new][:action] == "db_backup"
      schedule.sched_action = {:method=>"db_backup"}
    else
      schedule.sched_action = {:method=>"scan"}
    end

    if @edit[:new][:action] != "db_backup"
      unless ["global","my"].include?@edit[:new][:filter] # Unless a search filter is chosen
        # Build the filter expression
        exp = Hash.new
        if @edit[:new][:action] == "storage"
          case @edit[:new][:filter]
            when "ems"
              exp["CONTAINS"] = {"field"=>"Storage.ext_management_systems-name", "value"=>@edit[:new][:filter_value]}
            when "host"
              exp["CONTAINS"] = {"field"=>"Storage.hosts-name", "value"=>@edit[:new][:filter_value]}
            when "storage"
              exp["="] = {"field"=>"Storage-name", "value"=>@edit[:new][:filter_value]}
            else
              exp["IS NOT NULL"] = {"field"=>"Storage-name"}
          end
        elsif @edit[:new][:action] == "host"
          case @edit[:new][:filter]
            when "ems"
              exp["="] = {"field"=>"Host.ext_management_system-name", "value"=>@edit[:new][:filter_value]}
            when "cluster"
              unless @edit[:new][:filter_value].blank?
                exp["AND"] = [
                  {"="=>{"field"=>"Host-v_owning_cluster", "value"=>@edit[:new][:filter_value].split("__").first}},
                  {"="=>{"field"=>"Host-v_owning_datacenter", "value"=>@edit[:new][:filter_value].split("__").last}}
                ]
              end
            when "host"
              exp["="] = {"field"=>"Host-name", "value"=>@edit[:new][:filter_value]}
            else
              exp["IS NOT NULL"] = {"field"=>"Host-name"}
          end
        elsif @edit[:new][:action] == "emscluster"
          case @edit[:new][:filter]
            when "ems"
              exp["="] = {"field"=>"EmsCluster.ext_management_system-name", "value"=>@edit[:new][:filter_value]}
            when "cluster"
              unless @edit[:new][:filter_value].blank?
                exp["AND"] = [
                  {"="=>{"field"=>"EmsCluster-name", "value"=>@edit[:new][:filter_value].split("__").first}},
                  {"="=>{"field"=>"EmsCluster-v_parent_datacenter", "value"=>@edit[:new][:filter_value].split("__").last}}
                ]
              end
            else
              exp["IS NOT NULL"] = {"field"=>"EmsCluster-name"}
          end
        elsif @edit[:new][:action].ends_with?("check_compliance")
          case @edit[:new][:filter]
          when "ems"
            exp["="] = {"field"=>"#{@edit[:new][:action].split("_").first.capitalize}.ext_management_system-name", "value"=>@edit[:new][:filter_value]}
          when "cluster"
            unless @edit[:new][:filter_value].blank?
              exp["AND"] = [
                {"="=>{"field"=>"#{@edit[:new][:action].split("_").first.capitalize}-v_owning_cluster", "value"=>@edit[:new][:filter_value].split("__").first}},
                {"="=>{"field"=>"#{@edit[:new][:action].split("_").first.capitalize}-v_owning_datacenter", "value"=>@edit[:new][:filter_value].split("__").last}}
              ]
            end
          when "host"
            exp["="] = {"field"=>"Host-name", "value"=>@edit[:new][:filter_value]}
          when "vm"
              exp["="] = {"field"=>"Vm-name", "value"=>@edit[:new][:filter_value]}
          else
            exp["IS NOT NULL"] = {"field"=>"#{@edit[:new][:action].split("_").first.capitalize}-name"}
          end
        else
          model = @edit[:new][:action].starts_with?("vm") ? "Vm" : "MiqTemplate"
          case @edit[:new][:filter]
            when "ems"
              exp["="] = {"field"=>"#{model}.ext_management_system-name", "value"=>@edit[:new][:filter_value]}
            when "cluster"
              unless @edit[:new][:filter_value].blank?
                exp["AND"] = [
                  {"="=>{"field"=>"#{model}-v_owning_cluster", "value"=>@edit[:new][:filter_value].split("__").first}},
                  {"="=>{"field"=>"#{model}-v_owning_datacenter", "value"=>@edit[:new][:filter_value].split("__").last}}
                ]
              end
            when "host"
              exp["="] = {"field"=>"#{model}.host-name", "value"=>@edit[:new][:filter_value]}
            when "vm"
              exp["="] = {"field"=>"#{model}-name", "value"=>@edit[:new][:filter_value]}
            when "miq_template"
              exp["="] = {"field"=>"#{model}-name", "value"=>@edit[:new][:filter_value]}
            else
              exp["IS NOT NULL"] = {"field"=>"#{model}-name"}
          end
        end
        schedule.filter = MiqExpression.new(exp)
        schedule.miq_search = nil if schedule.miq_search  # Clear out any search relationship
      else  # Search filter chosen, set up relationship
        schedule.filter = nil                             # Clear out existing filter expression
        schedule.miq_search = @edit[:new][:filter_value] ? MiqSearch.find(@edit[:new][:filter_value]) : nil # Set up the search relationship
      end
    end
    schedule.run_at ||= Hash.new
    run_at = create_time_in_utc("#{@edit[:new][:start_date]} #{@edit[:new][:start_hour]}:#{@edit[:new][:start_min]}:00",
                                @edit[:tz])
    schedule.run_at[:start_time] = "#{run_at} Z"
    schedule.run_at[:tz] = @edit[:tz]
    schedule.run_at[:interval] ||= Hash.new
    schedule.run_at[:interval][:unit] = @edit[:new][:timer_typ].downcase
    case @edit[:new][:timer_typ].downcase
    when "monthly"
      schedule.run_at[:interval][:value] = @edit[:new][:timer_months]
    when "weekly"
      schedule.run_at[:interval][:value] = @edit[:new][:timer_weeks]
    when "daily"
      schedule.run_at[:interval][:value] = @edit[:new][:timer_days]
    when "hourly"
      schedule.run_at[:interval][:value] = @edit[:new][:timer_hours]
    else
      schedule.run_at[:interval].delete(:value)
    end
  end

  # Common Schedule button handler routines follow
  def process_schedules(schedules, task)
    process_elements(schedules, MiqSchedule, task)
  end

end
