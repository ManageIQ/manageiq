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

      #This is only because ops_controller tries to set form locals, otherwise we should not use the @edit variable
      @edit = {:sched_id => @schedule.id}

      settings = @schedule.depot_hash
      unless settings[:uri].nil?
        @protocol = DatabaseBackup.supported_depots[settings[:uri].split('://')[0]]
        @uri_prefix = settings[:uri].split('://')[0]
        @uri = settings[:uri].split('://')[1]
      end
      @log_userid = settings[:username]
      @log_password = settings[:password]
      @log_verify = settings[:password]

      # This is a hack to trick the controller into thinking we loaded an edit variable
      session[:edit] = {:key => "schedule_edit__#{@schedule.id || 'new'}"}

      schedule_build_edit_screen
      session[:changed] = false
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("se")
    end
  end

  def schedule_form_fields
    @schedule = MiqSchedule.find_by_id(params[:id])

    if @schedule.sched_action && @schedule.sched_action[:method] && @schedule.sched_action[:method] == "check_compliance"
      action_type = @schedule.towhat.downcase + "_" + @schedule.sched_action[:method]
    elsif @schedule.sched_action && @schedule.sched_action[:method] && @schedule.sched_action[:method] == "db_backup"
      action_type = @schedule.sched_action[:method]

      #have to create array to add <choose> on the top in the form
      @protocols_arr = Array.new
      DatabaseBackup.supported_depots.each do |p|
        @protocols_arr.push(p[1])
      end

      settings = @schedule.depot_hash
      unless settings[:uri].nil?
        @protocol = DatabaseBackup.supported_depots[settings[:uri].split('://')[0]]
        @uri_prefix = settings[:uri].split('://')[0]
        @uri = settings[:uri].split('://')[1]
      end
      @log_userid = settings[:username]
      @log_password = settings[:password]
      @log_verify = settings[:password]
    else
      if @schedule.towhat == nil
        action_type = "vm"
      else
        action_type ||= @schedule.towhat == "EmsCluster" ? "emscluster" : @schedule.towhat.underscore
      end
    end

    if @schedule.sched_action && @schedule.sched_action[:method] && @schedule.sched_action[:method] != "db_backup"
      if @schedule.miq_search                         # See if a search filter is attached
        filter_type = @schedule.miq_search.search_type == "user" ? "my" : "global"
        filter_value = @schedule.miq_search.id
      elsif @schedule.filter == nil                   # Set to All if not set
        filter_type = "all"
        filter_value = nil
      else
        key = @schedule.filter.exp.keys.first
        if key == "IS NOT NULL"                       # All
          filter_type = "all"
          filter_value = nil
        elsif key == "AND"                            # Cluster name and datacenter
          filter_type = "cluster"
          filter_value = @schedule.filter.exp[key][0]["="]["value"] + "__" + @schedule.filter.exp[key][1]["="]["value"]
        else
          case @schedule.filter.exp[key]["field"]
          when "Vm.ext_management_system-name",
               "MiqTemplate.ext_management_system-name",
               "Storage.ext_management_system-name",
               "Host.ext_management_system-name",
               "EmsCluster.ext_management_system-name"
            filter_type = "ems"
          when "Vm.host-name", "MiqTemplate.host-name", "Storage.host-name", "Host-name"
            filter_type = "host"
          when "Vm-name"
            filter_type = "vm"
          when "MiqTemplate-name"
            filter_type = "miq_template"
          when "Storage-name"
            filter_type = "storage"
          end

          filter_value = @schedule.filter.exp[key]["value"]
        end
      end
    end

    case filter_type
    when "vm"
      filtered_item_list = find_filtered(Vm, :all).sort_by { |vm| vm.name.downcase }.collect { |vm| vm.name }.uniq
    when "host"
      filtered_item_list = find_filtered(Host, :all).sort_by { |vm| vm.name.downcase }.collect { |vm| vm.name }.uniq
    when "ems"
      filtered_item_list = find_filtered(ExtManagementSystem, :all).sort_by { |vm| vm.name.downcase }.collect { |vm| vm.name }.uniq
    when "cluster"
      filtered_item_list = find_filtered(EmsCluster, :all).collect { |cluster|
        [cluster.name + "__" + cluster.v_parent_datacenter, cluster.v_qualified_desc]
      }.sort_by { |cluster| cluster.first.downcase }
    when "global"
      build_listnav_search_list("Vm")
      filtered_item_list = @def_searches.delete_if { |search| search.id == 0 }.collect { |search| [search.id, search.description] }
    when "my"
      build_listnav_search_list("Vm")
      filtered_item_list = @my_searches.collect { |search| [search.id, search.description] }
    else
      DatabaseBackup.supported_depots.each { |depot| @protocols_arr.push(depot[1]) }
    end

    render :json => {
      :action_type          => action_type,
      :filter_type          => filter_type,
      :filtered_item_list   => filtered_item_list,
      :filter_value         => filter_value,
      :schedule_description => @schedule.description,
      :schedule_enabled     => @schedule.enabled ? "1" : "0",
      :schedule_name        => @schedule.name,
      :schedule_timer_type  => @schedule.run_at[:interval][:unit].capitalize,
      :schedule_timer_value => @schedule.run_at[:interval][:value],
      :schedule_start_date  => @schedule.run_at[:start_time].strftime("%m/%d/%Y"),
      :schedule_start_hour  => @schedule.run_at[:start_time].strftime("%H"),
      :schedule_start_min   => @schedule.run_at[:start_time].strftime("%M"),
      :schedule_time_zone   => @schedule.run_at[:tz]
    }
  end

  def schedule_form_filter_type_field_changed
    case params[:filter_type]
    when "vm"
      filtered_item_list = find_filtered(Vm, :all).sort_by { |vm| vm.name.downcase }.collect { |vm| vm.name }.uniq
    when "host"
      filtered_item_list = find_filtered(Host, :all).sort_by { |vm| vm.name.downcase }.collect { |vm| vm.name }.uniq
    when "ems"
      filtered_item_list = find_filtered(ExtManagementSystem, :all).sort_by { |vm| vm.name.downcase }.collect { |vm| vm.name }.uniq
    when "cluster"
      filtered_item_list = find_filtered(EmsCluster, :all).collect { |cluster|
        [cluster.name + "__" + cluster.v_parent_datacenter, cluster.v_qualified_desc]
      }.sort_by { |cluster| cluster.first.downcase }
    when "global"
      build_listnav_search_list("Vm")
      filtered_item_list = @def_searches.delete_if { |search| search.id == 0 }.collect { |search| [search.id, search.description] }
    when "my"
      build_listnav_search_list("Vm")
      filtered_item_list = @my_searches.collect { |search| [search.id, search.description] }
    else
      DatabaseBackup.supported_depots.each { |depot| @protocols_arr.push(depot[1]) }
    end

    render :json => {:filtered_item_list => filtered_item_list}
  end

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
    present_action, msg = if enable
                            ['enable', _("No %s were selected to be enabled")]
                          else
                            ['disable', _("No %s were selected to be disabled")]
                          end

    schedules = find_checked_items
    if schedules.empty?
      add_flash(msg % ui_lookup(:models => "MiqSchedule"), :error)
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
    schedule_enable_disable(schedules, present_action)  unless schedules.empty?
    add_flash(msg % ui_lookup(:models => "MiqSchedule"), :info, true) unless flash_errors?
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

  def schedule_validate?(sched)
    valid = true
    if params[:action_typ] != "db_backup"
      if ["global","my"].include?(params[:filter_typ])
        if params[:filter_value].blank?  # Check for search filter chosen
          add_flash(_("%s must be selected") % "filter", :error)
          valid = false
        end
      elsif sched.filter.exp.keys.first != "IS NOT NULL" && params[:filter_value].blank? # Check for empty filter value
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

  def schedule_build_edit_screen
    @in_a_form = true

    build_listnav_search_list("Vm")
    build_listnav_search_list("MiqTemplate")
    build_listnav_search_list("Host")
    build_listnav_search_list("EmsCluster")
    build_listnav_search_list("Storage")
    @vm_global_filters = @def_searches.delete_if{|s| s.id == 0}.collect{|s| [s.description, s.id]}
    @vm_my_filters = @my_searches.collect{|s| [s.description, s.id]}
    @miq_template_global_filters = @def_searches.delete_if{|s| s.id == 0}.collect{|s| [s.description, s.id]}
    @miq_template_my_filters = @my_searches.collect{|s| [s.description, s.id]}
    @host_global_filters = @def_searches.delete_if{|s| s.id == 0}.collect{|s| [s.description, s.id]}
    @host_my_filters = @my_searches.collect{|s| [s.description, s.id]}
    @cluster_global_filters = @def_searches.delete_if{|s| s.id == 0}.collect{|s| [s.description, s.id]}
    @cluster_my_filters = @my_searches.collect{|s| [s.description, s.id]}
    @storage_global_filters = @def_searches.delete_if{|s| s.id == 0}.collect{|s| [s.description, s.id]}
    @storage_my_filters = @my_searches.collect{|s| [s.description, s.id]}

    build_schedule_options_for_select

    one_month_ago = (Time.now - 1.month).in_time_zone(session[:user_tz])
    @one_month_ago = {
      :year => one_month_ago.year,
      :month => one_month_ago.month - 1, # Javascript counts months 0-11
      :date => one_month_ago.day
    }
  end

  def schedule_set_record_vars(schedule)
    schedule.name = params[:name]
    schedule.description = params[:description]
    schedule.enabled = params[:enabled]

    if params[:action_typ] == "db_backup"
      schedule.towhat = "DatabaseBackup"
    elsif params[:action_typ].ends_with?("check_compliance")
      schedule.towhat = params[:action_typ].split("_").first.capitalize
    else
      schedule.towhat = params[:action_typ] == "emscluster" ? "EmsCluster" : params[:action_typ].camelcase
    end

    if ["vm", "miq_template"].include?(params[:action_typ])
      schedule.sched_action = {:method=>"vm_scan"}      # Default to vm_scan method for now
    elsif params[:action_typ].ends_with?("check_compliance")
      schedule.sched_action = {:method=>"check_compliance"}
    elsif params[:action_typ] == "db_backup"
      schedule.sched_action = {:method=>"db_backup"}
    else
      schedule.sched_action = {:method=>"scan"}
    end

    if params[:action_typ] != "db_backup"
      unless ["global","my"].include?(params[:filter_typ]) # Unless a search filter is chosen
        # Build the filter expression
        exp = Hash.new
        if params[:action_typ] == "storage"
          case params[:filter_typ]
            when "ems"
              exp["CONTAINS"] = {"field"=>"Storage.ext_management_systems-name", "value"=>params[:filter_value]}
            when "host"
              exp["CONTAINS"] = {"field"=>"Storage.hosts-name", "value"=>params[:filter_value]}
            when "storage"
              exp["="] = {"field"=>"Storage-name", "value"=>params[:filter_value]}
            else
              exp["IS NOT NULL"] = {"field"=>"Storage-name"}
          end
        elsif params[:action_typ] == "host"
          case params[:filter_typ]
            when "ems"
              exp["="] = {"field"=>"Host.ext_management_system-name", "value"=>params[:filter_value]}
            when "cluster"
              unless params[:filter_value].blank?
                exp["AND"] = [
                  {"="=>{"field"=>"Host-v_owning_cluster", "value"=>params[:filter_value].split("__").first}},
                  {"="=>{"field"=>"Host-v_owning_datacenter", "value"=>params[:filter_value].split("__").last}}
                ]
              end
            when "host"
              exp["="] = {"field"=>"Host-name", "value"=>params[:filter_value]}
            else
              exp["IS NOT NULL"] = {"field"=>"Host-name"}
          end
        elsif params[:action_typ] == "emscluster"
          case params[:filter_typ]
            when "ems"
              exp["="] = {"field"=>"EmsCluster.ext_management_system-name", "value"=>params[:filter_value]}
            when "cluster"
              unless params[:filter_value].blank?
                exp["AND"] = [
                  {"="=>{"field"=>"EmsCluster-name", "value"=>params[:filter_value].split("__").first}},
                  {"="=>{"field"=>"EmsCluster-v_parent_datacenter", "value"=>params[:filter_value].split("__").last}}
                ]
              end
            else
              exp["IS NOT NULL"] = {"field"=>"EmsCluster-name"}
          end
        elsif params[:action_typ].ends_with?("check_compliance")
          case params[:filter_typ]
          when "ems"
            exp["="] = {"field"=>"#{params[:action_typ].split("_").first.capitalize}.ext_management_system-name", "value"=>params[:filter_value]}
          when "cluster"
            unless params[:filter_value].blank?
              exp["AND"] = [
                {"="=>{"field"=>"#{params[:action_typ].split("_").first.capitalize}-v_owning_cluster", "value"=>params[:filter_value].split("__").first}},
                {"="=>{"field"=>"#{params[:action_typ].split("_").first.capitalize}-v_owning_datacenter", "value"=>params[:filter_value].split("__").last}}
              ]
            end
          when "host"
            exp["="] = {"field"=>"Host-name", "value"=>params[:filter_value]}
          when "vm"
              exp["="] = {"field"=>"Vm-name", "value"=>params[:filter_value]}
          else
            exp["IS NOT NULL"] = {"field"=>"#{params[:action_typ].split("_").first.capitalize}-name"}
          end
        else
          model = params[:action_typ].starts_with?("vm") ? "Vm" : "MiqTemplate"
          case params[:filter_typ]
            when "ems"
              exp["="] = {"field"=>"#{model}.ext_management_system-name", "value"=>params[:filter_value]}
            when "cluster"
              unless params[:filter_value].blank?
                exp["AND"] = [
                  {"="=>{"field"=>"#{model}-v_owning_cluster", "value"=>params[:filter_value].split("__").first}},
                  {"="=>{"field"=>"#{model}-v_owning_datacenter", "value"=>params[:filter_value].split("__").last}}
                ]
              end
            when "host"
              exp["="] = {"field"=>"#{model}.host-name", "value"=>params[:filter_value]}
            when "vm"
              exp["="] = {"field"=>"#{model}-name", "value"=>params[:filter_value]}
            when "miq_template"
              exp["="] = {"field"=>"#{model}-name", "value"=>params[:filter_value]}
            else
              exp["IS NOT NULL"] = {"field"=>"#{model}-name"}
          end
        end

        schedule.filter = MiqExpression.new(exp)
        schedule.miq_search = nil if schedule.miq_search  # Clear out any search relationship
      else  # Search filter chosen, set up relationship
        schedule.filter = nil                             # Clear out existing filter expression
        schedule.miq_search = params[:filter_value] ? MiqSearch.find(params[:filter_value]) : nil # Set up the search relationship
      end
    end

    schedule.run_at ||= Hash.new
    run_at = create_time_in_utc("#{params[:miq_date_1]} #{params[:start_hour]}:#{params[:start_min]}:00", params[:time_zone])
    schedule.run_at[:start_time] = "#{run_at} Z"
    schedule.run_at[:tz] = params[:time_zone]
    schedule.run_at[:interval] ||= {}
    schedule.run_at[:interval][:unit] = params[:timer_typ].downcase
    schedule.run_at[:interval][:value] = params[:timer_value]
  end

  # Common Schedule button handler routines follow
  def process_schedules(schedules, task)
    process_elements(schedules, MiqSchedule, task)
  end

  def build_schedule_options_for_select
    @action_type_options_for_select = [
      ["VM Analysis","vm"],
      ["Template Analysis","miq_template"],
      ["Host Analysis","host"],
      ["#{ui_lookup(:model=>'EmsCluster')} Analysis","emscluster"],
      ["#{ui_lookup(:model=>'Storage')} Analysis","storage"]
    ]
    @action_type_options_for_select.push(["VM Compliance Check","vm_check_compliance"]) if role_allows(:feature=>"vm_check_compliance")
    @action_type_options_for_select.push(["Host Compliance Check","host_check_compliance"]) if role_allows(:feature=>"host_check_compliance")
    @action_type_options_for_select.push(["Database Backup","db_backup"]) if DatabaseBackup.backup_supported?

    @vm_options_for_select = [
      ["All VMs","all"],
      ["All VMs for #{ui_lookup(:table=>"ext_management_systems")}","ems"],
      ["All VMs for #{ui_lookup(:table=>"ems_clusters")}","cluster"],
      ["All VMs for Host","host"],
      ["A single VM","vm"]
    ] +
      (@vm_global_filters.empty? ? [] : [["Global Filters", "global"]]) +
      (@vm_my_filters.empty? ? [] : [["My Filters", "my"]])

    @template_options_for_select = [
      ["All Templates","all"],
      ["All Templates for #{ui_lookup(:table=>"ext_management_systems")}","ems"],
      ["All Templates for #{ui_lookup(:table=>"ems_clusters")}","cluster"],
      ["All Templates for Host","host"],
      ["A single Template","miq_template"]
    ] +
      (@miq_template_global_filters.empty? ? [] : [["Global Filters", "global"]]) +
      (@miq_template_my_filters.empty? ? [] : [["My Filters", "my"]])

    @host_options_for_select = [
      ["All Hosts","all"],
      ["All Hosts for #{ui_lookup(:table=>"ext_management_systems")}","ems"],
      ["All Hosts for #{ui_lookup(:table=>"ems_clusters")}","cluster"],
      ["A single Host","host"]
    ] +
      (@host_global_filters.empty? ? [] : [["Global Filters", "global"]]) +
      (@host_my_filters.empty? ? [] : [["My Filters", "my"]])

    @cluster_options_for_select = [
      ["All Clusters","all"],
      ["All Clusters for #{ui_lookup(:table=>"ext_management_systems")}","ems"],
      ["A single Cluster","cluster"]
    ] +
      (@cluster_global_filters.empty? ? [] : [["Global Filters", "global"]]) +
      (@cluster_my_filters.empty? ? [] : [["My Filters", "my"]])

    @storage_options_for_select = [
      ["All Datastores","all"],
      ["All Datastores for Host","host"],
      ["All Datastores for #{ui_lookup(:table=>"ext_management_systems")}","ems"],
      ["A single Datastore","storage"]
    ] +
      (@storage_global_filters.empty? ? [] : [["Global Filters", "global"]]) +
      (@storage_my_filters.empty? ? [] : [["My Filters", "my"]])

    @protocols_arr = []
    DatabaseBackup.supported_depots.each { |depot| @protocols_arr.push(depot[1]) }
    @database_backup_options_for_select = @protocols_arr.sort
  end
end
