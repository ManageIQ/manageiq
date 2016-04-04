module OpsController::Settings::Schedules
  extend ActiveSupport::Concern

  # Show the main Schedules list view
  def schedules_list
    schedule_build_list
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page]
      render :update do |page|
        page.replace("gtl_div", :partial => "layouts/x_gtl", :locals => {:action_url => "schedules_list"})
        page.replace_html("paging_div", :partial => "layouts/x_pagingcontrols")
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

    if @selected_schedule.filter.kind_of?(MiqExpression)
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
      @schedule = MiqSchedule.find_by_id(params[:id])
      if !@schedule || @schedule.id.blank?
        add_flash(_("Add of new %{model} was cancelled by the user") % {:model => ui_lookup(:model => "MiqSchedule")})
      else
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => "MiqSchedule"), :name => @schedule.name})
      end
      get_node_info(x_node)
      @schedule = nil
      replace_right_cell(@nodetype)
    when "save", "add"
      schedule = params[:id] != "new" ? MiqSchedule.find_by_id(params[:id]) : MiqSchedule.new(:userid => session[:userid])

      # This should be changed to something like schedule.changed? and schedule.changes
      # when we have a version of Rails that supports detecting changes on serialized
      # fields
      old_schedule_attributes = schedule.attributes.clone
      old_schedule_attributes.merge("filter" => old_schedule_attributes["filter"].try(:to_human))
      old_schedule_attributes.merge("run_at" => {:start_time => schedule.run_at[:start_time],
                                                 :tz         => schedule.run_at[:tz],
                                                 :interval   => {:unit  => schedule.run_at[:interval][:unit],
                                                                 :value => schedule.run_at[:interval][:value]
                                                                }
                                                }) if schedule.run_at
      schedule_set_basic_record_vars(schedule)
      schedule_set_record_vars(schedule)
      schedule_set_timer_record_vars(schedule)
      schedule_validate?(schedule)
      begin
        schedule.save!
      rescue StandardError => bang
        add_flash(_("Error when adding a new schedule: %{message}") % {:message => bang.message}, :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      else
        AuditEvent.success(build_saved_audit_hash(old_schedule_attributes, schedule, params[:button] == "add"))
        add_flash(_("%{model} \"%{name}\" was saved") %
                      {:model => ui_lookup(:model => "MiqSchedule"), :name => schedule.name})
        if params[:button] == "add"
          self.x_node  = "xx-msc"
          schedules_list
          settings_get_info("st")
        else
          @selected_schedule = schedule
          get_node_info(x_node)
        end
        replace_right_cell("root", [:settings])
      end
    when "reset", nil # Reset or first time in
      obj = find_checked_items
      obj[0] = params[:id] if obj.blank? && params[:id]
      @schedule = params[:typ] == "new" ? MiqSchedule.new(:userid => session[:userid]) : MiqSchedule.find(obj[0])          # Get existing or new record

      # This is only because ops_controller tries to set form locals, otherwise we should not use the @edit variable
      @edit = {:sched_id => @schedule.id}

      depot             = @schedule.file_depot
      @uri_prefix, @uri = depot.try(:uri).to_s.split('://')
      @protocol         = DatabaseBackup.supported_depots[@uri_prefix]
      @log_userid       = depot.try(:authentication_userid)
      @log_password     = depot.try(:authentication_password)
      @log_verify       = depot.try(:authentication_password)

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
    schedule = MiqSchedule.find_by_id(params[:id])

    if schedule_check_compliance?(schedule)
      action_type = schedule.towhat.downcase + "_" + schedule.sched_action[:method]
    elsif schedule_db_backup?(schedule)
      action_type     = schedule.sched_action[:method]
      depot           = schedule.file_depot
      uri_prefix, uri = depot.try(:uri).to_s.split('://')
      protocol        = DatabaseBackup.supported_depots[uri_prefix]
      depot_name      = depot.try(:name)
      log_userid      = depot.try(:authentication_userid)
    else
      if schedule.towhat.nil?
        action_type = "vm"
      else
        action_type ||= schedule.towhat == "EmsCluster" ? "emscluster" : schedule.towhat.underscore
      end
    end

    filter_type, filter_value = determine_filter_type_and_value(schedule)
    filtered_item_list = build_filtered_item_list(action_type, filter_type)
    run_at = schedule.run_at[:start_time].in_time_zone(schedule.run_at[:tz])

    render :json => {
      :action_type          => action_type,
      :depot_name           => depot_name,
      :filter_type          => filter_type,
      :filter_value         => filter_value,
      :filtered_item_list   => filtered_item_list,
      :log_userid           => log_userid ? log_userid : "",
      :protocol             => protocol,
      :schedule_description => schedule.description,
      :schedule_enabled     => schedule.enabled ? "1" : "0",
      :schedule_name        => schedule.name,
      :schedule_start_date  => run_at.strftime("%m/%d/%Y"),
      :schedule_start_hour  => run_at.strftime("%H").to_i,
      :schedule_start_min   => run_at.strftime("%M").to_i,
      :schedule_time_zone   => schedule.run_at[:tz],
      :schedule_timer_type  => schedule.run_at[:interval][:unit].capitalize,
      :schedule_timer_value => schedule.run_at[:interval][:value].to_i,
      :uri                  => uri,
      :uri_prefix           => uri_prefix
    }
  end

  def schedule_form_filter_type_field_changed
    filtered_item_list = build_filtered_item_list(params[:action_type], params[:filter_type])

    render :json => {:filtered_item_list => filtered_item_list}
  end

  def schedule_delete
    assert_privileges("schedule_delete")
    schedules = []
    if !params[:id] # showing a list
      schedules = find_checked_items
      if schedules.empty?
        add_flash(_("No %{model} were selected for deletion") % {:model => ui_lookup(:tables => "miq_schedule")},
                  :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      end
      process_schedules(schedules, "destroy") unless schedules.empty?
      schedule_build_list
      settings_get_info("st")
      replace_right_cell("root", [:settings])
    else # showing 1 schedule, delete it
      if params[:id].nil? || MiqSchedule.find_by_id(params[:id]).nil?
        add_flash(_("%{table} no longer exists") % {:table => ui_lookup(:table => "miq_schedule")}, :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      else
        schedules.push(params[:id])
      end
      process_schedules(schedules, "destroy") unless schedules.empty?
      self.x_node = "xx-msc"
      get_node_info(x_node)
      replace_right_cell(x_node, [:settings])
    end
  end

  def schedule_toggle(enable)
    msg = if enable
            _("The selected Schedules were enabled")
          else
            _("The selected Schedules were disabled")
          end

    schedules = find_checked_items
    if schedules.empty?
      add_flash(msg, :error)
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    end
    schedule_enable_disable(schedules, enable)  unless schedules.empty?
    add_flash(msg, :info, true) unless flash_errors?
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

  def log_depot_validate
    if params[:log_password]
      file_depot = FileDepot.new
    else
      id = params[:id] || params[:backup_schedule_type]
      file_depot = MiqSchedule.find_by_id(id).file_depot
    end
    uri_settings = build_uri_settings(file_depot)
    begin
      MiqSchedule.new.verify_file_depot(uri_settings)
    rescue StandardError => bang
      add_flash(_("Error during 'Validate': %{message}") % {:message => bang.message}, :error)
    else
      add_flash(_('Depot Settings successfuly validated'))
    end
    render :update do |page|
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
    end
  end

  private

  def build_saved_audit_hash(old_schedule_attributes, new_schedule, add)
    name  = new_schedule.respond_to?(:name) ? new_schedule.name : new_schedule.description
    msg   = if add
              _("[%{name}] Record added (") % {:name => name}
            else
              _("[%{name}] Record updated (") % {:name => name}
            end
    event = "#{new_schedule.class.to_s.downcase}_record_#{add ? "add" : "update"}"

    attribute_difference = new_schedule.attributes.to_a - old_schedule_attributes.to_a
    attribute_difference = Hash[*attribute_difference.flatten]

    difference_messages = []

    attribute_difference.each do |key, value|
      difference_messages << _("%{key} changed to %{value}") % {:key => key, :value => value}
    end

    msg = msg + difference_messages.join(", ") + ")"

    {
      :event        => event,
      :target_id    => new_schedule.id,
      :target_class => new_schedule.class.base_class.name,
      :userid       => session[:userid],
      :message      => msg
    }
  end

  def schedule_check_compliance?(schedule)
    schedule.sched_action && schedule.sched_action[:method] && schedule.sched_action[:method] == "check_compliance"
  end

  def schedule_db_backup?(schedule)
    schedule.sched_action && schedule.sched_action[:method] && schedule.sched_action[:method] == "db_backup"
  end

  def schedule_towhat_from_params_action
    case params[:action_typ]
    when "db_backup"          then "DatabaseBackup"
    when /check_compliance\z/ then params[:action_typ].split("_").first.capitalize
    when "emscluster"         then "EmsCluster"
    else                           params[:action_typ].camelcase
    end
  end

  def schedule_method_from_params_action
    case params[:action_typ]
    when "vm", "miq_template" then "vm_scan"  # Default to vm_scan method for now
    when /check_compliance\z/ then "check_compliance"
    when "db_backup"          then "db_backup"
    else                           "scan"
    end
  end

  def build_filtered_item_list(action_type, filter_type)
    case filter_type
    when "vm"
      filtered_item_list = find_filtered(Vm).sort_by { |vm| vm.name.downcase }.collect(&:name).uniq
    when "miq_template"
      filtered_item_list =
        find_filtered(MiqTemplate).sort_by { |miq_template| miq_template.name.downcase }.collect(&:name).uniq
    when "host"
      filtered_item_list = find_filtered(Host).sort_by { |vm| vm.name.downcase }.collect(&:name).uniq
    when "ems"
      filtered_item_list = find_filtered(ExtManagementSystem).sort_by { |vm| vm.name.downcase }.collect(&:name).uniq
    when "cluster"
      filtered_item_list = find_filtered(EmsCluster).collect do |cluster|
        [cluster.name + "__" + cluster.v_parent_datacenter, cluster.v_qualified_desc]
      end.sort_by { |cluster| cluster.first.downcase }.uniq
    when "storage"
      filtered_item_list = find_filtered(Storage).sort_by { |ds| ds.name.downcase }.collect(&:name).uniq
    when "global"
      if action_type == "miq_template"
        action_type = action_type.camelize
      else
        action_type = action_type.split("_").first.capitalize
      end
      build_listnav_search_list(action_type)
      filtered_item_list = @def_searches.delete_if { |search| search.id == 0 }.collect { |search| [search.id, search.description] }
    when "my"
      build_listnav_search_list("Vm")
      filtered_item_list = @my_searches.collect { |search| [search.id, search.description] }
    else
      filtered_item_list = []
      DatabaseBackup.supported_depots.each { |depot| filtered_item_list.push(depot[1]) }
    end

    filtered_item_list
  end

  def determine_filter_type_and_value(schedule)
    if schedule.sched_action && schedule.sched_action[:method] && schedule.sched_action[:method] != "db_backup"
      if schedule.miq_search                         # See if a search filter is attached
        filter_type = schedule.miq_search.search_type == "user" ? "my" : "global"
        filter_value = schedule.miq_search.id
      elsif schedule.filter.nil?                   # Set to All if not set
        filter_type = "all"
        filter_value = nil
      else
        key = schedule.filter.exp.keys.first
        if key == "IS NOT NULL"                       # All
          filter_type = "all"
          filter_value = nil
        elsif key == "AND"                            # Cluster name and datacenter
          filter_type = "cluster"
          filter_value = schedule.filter.exp[key][0]["="]["value"] + "__" + schedule.filter.exp[key][1]["="]["value"]
        else
          case schedule.filter.exp[key]["field"]
          when "Vm.ext_management_system-name",
               "MiqTemplate.ext_management_system-name",
               "Storage.ext_management_systems-name",
               "Host.ext_management_system-name",
               "EmsCluster.ext_management_system-name"
            filter_type = "ems"
          when "Vm.host-name", "MiqTemplate.host-name", "Storage.hosts-name", "Host-name"
            filter_type = "host"
          when "Vm-name"
            filter_type = "vm"
          when "MiqTemplate-name"
            filter_type = "miq_template"
          when "Storage-name"
            filter_type = "storage"
          end

          filter_value = schedule.filter.exp[key]["value"]
        end
      end
    end

    return filter_type, filter_value
  end

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
    @sortcol = session[:schedule_sortcol].nil? ? 0 : session[:schedule_sortcol].to_i
    @sortdir = session[:schedule_sortdir].nil? ? "ASC" : session[:schedule_sortdir]

    @view, @pages = get_view(MiqSchedule, :conditions => ["prod_default!=? or prod_default IS NULL And adhoc IS NULL", "system"]) # Get the records (into a view) and the paginator

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    session[:schedule_sortcol] = @sortcol
    session[:schedule_sortdir] = @sortdir
  end

  def schedule_validate?(sched)
    valid = true
    if params[:action_typ] != "db_backup"
      if %w(global my).include?(params[:filter_typ])
        if params[:filter_value].blank?  # Check for search filter chosen
          add_flash(_("Filter must be selected"), :error)
          valid = false
        end
      elsif sched.filter.exp.keys.first != "IS NOT NULL" && params[:filter_value].blank? # Check for empty filter value
        add_flash(_("Filter value must be selected"), :error)
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
    valid
  end

  def schedule_build_edit_screen
    @vm_global_filters, @vm_my_filters                     = build_global_and_my_filters("Vm")
    @miq_template_global_filters, @miq_template_my_filters = build_global_and_my_filters("MiqTemplate")
    @host_global_filters, @host_my_filters                 = build_global_and_my_filters("Host")
    @cluster_global_filters, @cluster_my_filters           = build_global_and_my_filters("EmsCluster")
    @storage_global_filters, @storage_my_filters           = build_global_and_my_filters("Storage")

    build_schedule_options_for_select

    one_month_ago = Time.zone.now - 1.month
    @one_month_ago = {
      :year  => one_month_ago.year,
      :month => one_month_ago.month - 1, # Javascript counts months 0-11
      :date  => one_month_ago.day
    }
  end

  def build_global_and_my_filters(type)
    build_listnav_search_list(type)
    global_filters = @def_searches.reject { |s| s.id == 0 }.collect { |s| [s.description, s.id] }
    my_filters = @my_searches.collect { |s| [s.description, s.id] }

    return global_filters, my_filters
  end

  def schedule_set_record_vars(schedule)
    schedule.towhat       = schedule_towhat_from_params_action
    schedule.sched_action = {:method => schedule_method_from_params_action}

    if params[:action_typ] == "db_backup"
      schedule.filter = nil
      depot = schedule.file_depot
      uri_settings = build_uri_settings(depot)
      uri_settings[:name] = params[:depot_name]
      uri_settings[:save] = true
      schedule.verify_file_depot(uri_settings)
    elsif %w(global my).include?(params[:filter_typ])  # Search filter chosen, set up relationship
      schedule.filter     = nil  # Clear out existing filter expression
      schedule.miq_search = params[:filter_value] ? MiqSearch.find(params[:filter_value]) : nil # Set up the search relationship
    else  # Build the filter expression
      schedule.filter     = MiqExpression.new(build_search_filter_from_params)
      schedule.miq_search = nil if schedule.miq_search  # Clear out any search relationship
    end
  end

  def build_search_filter_from_params
    case params[:action_typ]
    when "storage"
      case params[:filter_typ]
      when "ems"     then {"CONTAINS" => {"field" => "Storage.ext_management_systems-name", "value" => params[:filter_value]}}
      when "host"    then {"CONTAINS" => {"field" => "Storage.hosts-name", "value" => params[:filter_value]}}
      when "storage" then {"=" => {"field" => "Storage-name", "value" => params[:filter_value]}}
      else                {"IS NOT NULL" => {"field" => "Storage-name"}}
      end
    when "host"
      case params[:filter_typ]
      when "cluster"
        unless params[:filter_value].blank?
          {"AND" => [
            {"=" => {"field" => "Host-v_owning_cluster", "value" => params[:filter_value].split("__").first}},
            {"=" => {"field" => "Host-v_owning_datacenter", "value" => params[:filter_value].split("__").size == 1 ? "" : params[:filter_value].split("__").last}}
          ]}
        end
      when "ems"  then {"=" => {"field" => "Host.ext_management_system-name", "value" => params[:filter_value]}}
      when "host" then {"=" => {"field" => "Host-name", "value" => params[:filter_value]}}
      else             {"IS NOT NULL" => {"field" => "Host-name"}}
      end
    when "emscluster"
      case params[:filter_typ]
      when "cluster"
        unless params[:filter_value].blank?
          {"AND" => [
            {"=" => {"field" => "EmsCluster-name", "value" => params[:filter_value].split("__").first}},
            {"=" => {"field" => "EmsCluster-v_parent_datacenter", "value" => params[:filter_value].split("__").size == 1 ? "" : params[:filter_value].split("__").last}}
          ]}
        end
      when "ems" then {"=" => {"field" => "EmsCluster.ext_management_system-name", "value" => params[:filter_value]}}
      else            {"IS NOT NULL" => {"field" => "EmsCluster-name"}}
      end
    when /check_compliance\z/
      case params[:filter_typ]
      when "cluster"
        unless params[:filter_value].blank?
          {"AND" => [
            {"=" => {"field" => "#{params[:action_typ].split("_").first.capitalize}-v_owning_cluster", "value" => params[:filter_value].split("__").first}},
            {"=" => {"field" => "#{params[:action_typ].split("_").first.capitalize}-v_owning_datacenter", "value" => params[:filter_value].split("__").size == 1 ? "" : params[:filter_value].split("__").last}}
          ]}
        end
      when "ems"  then {"=" => {"field" => "#{params[:action_typ].split("_").first.capitalize}.ext_management_system-name", "value" => params[:filter_value]}}
      when "host" then {"=" => {"field" => "Host-name", "value" => params[:filter_value]}}
      when "vm"   then {"=" => {"field" => "Vm-name", "value" => params[:filter_value]}}
      else             {"IS NOT NULL" => {"field" => "#{params[:action_typ].split("_").first.capitalize}-name"}}
      end
    else
      model = params[:action_typ].starts_with?("vm") ? "Vm" : "MiqTemplate"
      case params[:filter_typ]
      when "cluster"
        unless params[:filter_value].blank?
          {"AND" => [
            {"=" => {"field" => "#{model}-v_owning_cluster", "value" => params[:filter_value].split("__").first}},
            {"=" => {"field" => "#{model}-v_owning_datacenter", "value" => params[:filter_value].split("__").size == 1 ? "" : params[:filter_value].split("__").last}}
          ]}
        end
      when "ems"          then {"=" => {"field" => "#{model}.ext_management_system-name", "value" => params[:filter_value]}}
      when "host"         then {"=" => {"field" => "#{model}.host-name", "value" => params[:filter_value]}}
      when "miq_template", "vm"
                          then {"=" => {"field" => "#{model}-name", "value" => params[:filter_value]}}
      else                     {"IS NOT NULL" => {"field" => "#{model}-name"}}
      end
    end
  end

  # Common Schedule button handler routines follow
  def process_schedules(schedules, task)
    process_elements(schedules, MiqSchedule, task)
  end

  def build_schedule_options_for_select
    @action_type_options_for_select = [
      [_("VM Analysis"), "vm"],
      [_("Template Analysis"), "miq_template"],
      [_("Host Analysis"), "host"],
      [_("%{model} Analysis") % {:model => ui_lookup(:model => 'EmsCluster')}, "emscluster"],
      [_("%{model} Analysis") % {:model => ui_lookup(:model => 'Storage')}, "storage"]
    ]
    if role_allows(:feature => "vm_check_compliance")
      @action_type_options_for_select.push([_("VM Compliance Check"), "vm_check_compliance"])
    end
    if role_allows(:feature => "host_check_compliance")
      @action_type_options_for_select.push([_("Host Compliance Check"), "host_check_compliance"])
    end
    @action_type_options_for_select.push([_("Database Backup"), "db_backup"])

    @vm_options_for_select = [
      [_("All VMs"), "all"],
      [_("All VMs for %{table}") % {:table => ui_lookup(:table => "ext_management_systems")}, "ems"],
      [_("All VMs for %{table}") % {:table => ui_lookup(:table => "ems_clusters")}, "cluster"],
      [_("All VMs for Host"), "host"],
      [_("A single VM"), "vm"]
    ] +
                             (@vm_global_filters.empty? ? [] : [[_("Global Filters"), "global"]]) +
                             (@vm_my_filters.empty? ? [] : [[_("My Filters"), "my"]])

    @template_options_for_select = [
      [_("All Templates"), "all"],
      [_("All Templates for %{table}") % {:table => ui_lookup(:table => "ext_management_systems")}, "ems"],
      [_("All Templates for %{table}") % {:table => ui_lookup(:table => "ems_clusters")}, "cluster"],
      [_("All Templates for Host"), "host"],
      [_("A single Template"), "miq_template"]
    ] +
                                   (@miq_template_global_filters.empty? ? [] : [[_("Global Filters"), "global"]]) +
                                   (@miq_template_my_filters.empty? ? [] : [[_("My Filters"), "my"]])

    @host_options_for_select = [
      [_("All Hosts"), "all"],
      [_("All Hosts for %{table}") % {:table => ui_lookup(:table => "ext_management_systems")}, "ems"],
      [_("All Hosts for %{table}") % {:table => ui_lookup(:table => "ems_clusters")}, "cluster"],
      [_("A single Host"), "host"]
    ] +
                               (@host_global_filters.empty? ? [] : [[_("Global Filters"), "global"]]) +
                               (@host_my_filters.empty? ? [] : [[_("My Filters"), "my"]])

    @cluster_options_for_select = [
      [_("All Clusters"), "all"],
      [_("All Clusters for %{table}") % {:table => ui_lookup(:table => "ext_management_systems")}, "ems"],
      [_("A single Cluster"), "cluster"]
    ] +
                                  (@cluster_global_filters.empty? ? [] : [[_("Global Filters"), "global"]]) +
                                  (@cluster_my_filters.empty? ? [] : [[_("My Filters"), "my"]])

    @storage_options_for_select = [
      [_("All Datastores"), "all"],
      [_("All Datastores for Host"), "host"],
      [_("All Datastores for %{table}") % {:table => ui_lookup(:table => "ext_management_systems")}, "ems"],
      [_("A single Datastore"), "storage"]
    ] +
                                  (@storage_global_filters.empty? ? [] : [[_("Global Filters"), "global"]]) +
                                  (@storage_my_filters.empty? ? [] : [[_("My Filters"), "my"]])

    build_db_options_for_select
  end

  def build_db_options_for_select
    @protocols_arr = []
    DatabaseBackup.supported_depots.each { |depot| @protocols_arr.push(depot[1]) }
    @database_backup_options_for_select = @protocols_arr.sort
  end

  def schedule_set_basic_record_vars(schedule)
    schedule.name = params[:name]
    schedule.description = params[:description]
    schedule.enabled = params[:enabled] || "off"
  end

  def schedule_set_timer_record_vars(schedule)
    schedule.run_at ||= {}
    schedule.run_at[:tz] = params[:time_zone]
    schedule_set_start_time_record_vars(schedule)
    schedule_set_interval_record_vars(schedule)
  end

  def schedule_set_start_time_record_vars(schedule)
    run_at = create_time_in_utc("#{params[:start_date]} #{params[:start_hour]}:#{params[:start_min]}:00",
                                params[:time_zone])
    schedule.run_at[:start_time] = "#{run_at} Z"
  end

  def schedule_set_interval_record_vars(schedule)
    schedule.run_at[:interval] ||= {}
    schedule.run_at[:interval][:unit] = params[:timer_typ].downcase
    schedule.run_at[:interval][:value] = params[:timer_value]
  end

  def build_uri_settings(file_depot)
    uri_settings = {}
    type = FileDepot.depot_description_to_class(params[:log_protocol])
    if type.try(:requires_credentials?)
      log_password = params[:log_password] ? params[:log_password] : file_depot.try(:authentication_password)
      uri_settings = {:username => params[:log_userid], :password => log_password}
    end
    uri_settings[:uri] = "#{params[:uri_prefix]}://#{params[:uri]}"
    uri_settings[:uri_prefix] = params[:uri_prefix]
    uri_settings
  end
end
