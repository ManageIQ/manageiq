module ReportController::Widgets
  extend ActiveSupport::Concern

  def widget_refresh
    assert_privileges("widget_refresh")
    replace_right_cell
  end

  def widget_copy
    assert_privileges("widget_copy")
    @widget = MiqWidget.new
    @in_a_form = true
    unless params[:id]
      obj = find_checked_items
      @_params[:id] = obj[0] unless obj.empty?
    end
    widget = find_by_id_filtered(MiqWidget, params[:id])
    @widget.title = widget.title
    @widget.description = widget.description
    @widget.resource = widget.resource
    @widget.miq_schedule = widget.miq_schedule  # Need original sched to get options for copy
    @widget.options = widget.options
    @widget.visibility = widget.visibility
    @widget.enabled = widget.enabled
    @widget.content_type = widget.content_type
    widget.miq_widget_shortcuts.each do |ws|  # Need to make new widget_shortcuts to leave the originals alone
      new_ws = MiqWidgetShortcut.new(:sequence => ws.sequence, :description => ws.description, :miq_shortcut_id => ws.miq_shortcut_id)
      @widget.miq_widget_shortcuts.push(new_ws)
    end

    widget_set_form_vars
    session[:changed] = false
    @lock_tree = true
    replace_right_cell
  end

  def widget_new
    assert_privileges("widget_new")
    widget_edit
  end

  def widget_edit
    case params[:button]
    when "cancel"
      @widget = MiqWidget.find_by_id(session[:edit][:widget_id]) if session[:edit] && session[:edit][:widget_id]
      if !@widget || @widget.id.blank?
        add_flash(_("Add of new %{model} was cancelled by the user") % {:model => ui_lookup(:model => "MiqWidget")})
      else
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => "MiqWidget"), :name => @widget.name})
      end
      get_node_info
      @widget = nil
      @edit = session[:edit] = nil  # clean out the saved info
      replace_right_cell
    when "add", "save"
      assert_privileges("widget_#{params[:id] ? "edit" : "new"}")
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("widget_edit__#{id}", "replace_cell__explorer")
      widget_get_form_vars # get current record(@widget) of MiqWidget
      widget_set_record_vars(@widget)
      if widget_validate_entries && @widget.save_with_shortcuts(@edit[:new][:shortcuts].to_a)
        AuditEvent.success(build_saved_audit(@widget, @edit))
        add_flash(_("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:model => "MiqWidget"),
                                                         :name  => @widget.title})
        params[:id] = @widget.id.to_s   # reset id in params for show
        # Build the filter expression and attach widget to schedule filter
        exp = {}
        exp["="] = {"field" => "MiqWidget-id", "value" => @widget.id}
        @edit[:schedule].filter = MiqExpression.new(exp)
        @edit[:schedule].save
        @edit = session[:edit] = nil    # clean out the saved info
        # @schedule = nil
        replace_right_cell(:replace_trees => [:widgets])
      else
        @widget.errors.each do |field, msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        @changed = session[:changed] = (@edit[:new] != @edit[:current])
        javascript_flash
      end
    else
      add_flash(_("All changes have been reset"), :warning) if params[:button] == "reset"
      @widget = params[:id] && params[:id] != "new" ? MiqWidget.find_by_id(params[:id]) :
          MiqWidget.new # Get existing or new record
      widget_set_form_vars
      session[:changed] = false
      @in_a_form = true
      @lock_tree = true
      replace_right_cell
    end
  end

  # Delete all selected or single displayed action(s)
  def widget_delete
    assert_privileges("widget_delete")
    widgets = find_checked_items
    if !params[:id].nil? && MiqWidget.find_by_id(params[:id]).nil?
      add_flash(_("%{model} no longer exists") % {:model => ui_lookup(:models => "MiqWidget")},
                :error)
    else
      widgets.push(params[:id]) if params[:id]
    end
    w = MiqWidget.find_by_id(widgets[0])        # temp var to determine the parent node of deleted items
    process_widgets(widgets, "destroy") unless widgets.empty?
    nodes = x_node.split('-')
    self.x_node = "#{nodes[0]}-#{WIDGET_CONTENT_TYPE.invert[w.content_type]}"
    replace_right_cell(:replace_trees => [:widgets])
  end

  def widget_generate_content
    assert_privileges("widget_generate_content")
    w = MiqWidget.find_by_id(params[:id])
    begin
      w.queue_generate_content
    rescue => bang
      add_flash(_("Widget content generation error: %{message}") % {:message => bang.message}, :error)
    else
      add_flash(_("Content generation for this Widget has been initiated"))
    end
    # refresh widget show to update buttons
    widget_refresh
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def widget_form_field_changed
    return unless load_edit("widget_edit__#{params[:id]}", "replace_cell__explorer")
    widget_get_form_vars
    render :update do |page|
      page << javascript_prologue
      if params[:filter_typ]
        @edit[:new][:subfilter] = nil
        @edit[:new][:repfilter] = @reps = nil
        @replace_filter_div = true
      elsif params[:subfilter_typ]
        @edit[:new][:repfilter] = nil
        @replace_filter_div = true
      elsif params[:repfilter_typ] || params[:chosen_pivot1] || params[:chosen_pivot2] || params[:chosen_pivot3] ||
            params[:feed_type] || params[:rss_url]
        @replace_filter_div = true
      end
      if @replace_filter_div
        page.replace("form_filter_div", :partial => "widget_form_filter")
        page << "miqInitDashboardCols();"
      end

      if params[:visibility_typ]
        page.replace("form_role_visibility", :partial => "layouts/role_visibility", :locals => {:rec_id => (@widget.id.to_s || "new"), :action => "widget_form_field_changed"})
      end

      javascript_for_timer_type(params[:timer_typ]).each { |js| page << js }

      if params[:time_zone]
        page << "ManageIQ.calendar.calDateFrom = new Date(#{(Time.zone.now - 1.month).in_time_zone(@edit[:tz]).strftime("%Y,%m,%d")});"
        page << "miqBuildCalendar();"
        page << "$('#miq_date_1').val('#{@edit[:new][:timer].start_date}');"
        page << "$('#start_hour').val('#{@edit[:new][:timer].start_hour.to_i}');"
        page << "$('#start_min').val('#{@edit[:new][:timer].start_min.to_i}');"
        page.replace_html("tz_span", @timezone_abbr)
      end
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  # Shortcut was dropped, reorder the :shortcuts hash
  def widget_shortcut_dd_done
    new_hash = {}
    params[:col1].each { |sc| new_hash[sc.to_i] = @edit[:new][:shortcuts][sc.to_i] }
    @edit[:new][:shortcuts] = new_hash
    @edit[:new][:shortcut_keys] = @edit[:new][:shortcuts].keys  # Save the keys array so we can compare the hash order
    render :update do |page|
      page << javascript_prologue
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  # Shortcut was removed
  def widget_shortcut_remove
    return unless load_edit("widget_edit__#{params[:id]}", "replace_cell__explorer")
    @widget = @edit[:widget_id] ? MiqWidget.find_by_id(@edit[:widget_id]) : MiqWidget.new
    @edit[:new][:shortcuts].delete(params[:shortcut].to_i)
    @edit[:new][:shortcut_keys] = @edit[:new][:shortcuts].keys  # Save the keys array so we can compare the hash order
    @edit[:avail_shortcuts] = widget_build_avail_shortcuts
    render :update do |page|
      page << javascript_prologue
      page.replace("form_filter_div", :partial => "widget_form_filter")
      page << "miqInitDashboardCols();"
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  # Shortcut text reset
  def widget_shortcut_reset
    return unless load_edit("widget_edit__#{params[:id]}", "replace_cell__explorer")
    @widget = @edit[:widget_id] ? MiqWidget.find_by_id(@edit[:widget_id]) : MiqWidget.new
    @edit[:new][:shortcuts][params[:shortcut].to_i] = MiqShortcut.find_by_id(params[:shortcut].to_i).description
    render :update do |page|
      page << javascript_prologue
      page.replace("form_filter_div", :partial => "widget_form_filter")
      page << "miqInitDashboardCols();"
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  def get_all_widgets(nodeid = nil, rep_id = nil)
    @force_no_grid_xml   = true
    @gtl_type            = "list"
    @ajax_paging_buttons = true
    @no_checkboxes = @showlinks = true if x_active_tree != "report"
    #   @embedded = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end

    @sortcol = session["#{x_active_tree}_sortcol".to_sym].nil? ? 0 : session["#{x_active_tree}_sortcol".to_sym].to_i
    @sortdir = session["#{x_active_tree}_sortdir".to_sym].nil? ? "DESC" : session["#{x_active_tree}_sortdir".to_sym]
    if nodeid.nil? && rep_id.nil?
      # show all widgets
      @view, @pages = get_view(MiqWidget, :association => "all")
    else
      # show only specific type
      if !rep_id
        @view, @pages = get_view(MiqWidget, :where_clause => ["content_type=?", nodeid])
      else
        # get all widgets for passed in report id
        @widget_nodes = MiqWidget.where(:content_type => "report", :resource_id => rep_id)
      end
    end

    if x_active_tree == :widgets_tree
      # dont need to set these for report show screen
      @right_cell_div     = "widget_list"
      @right_cell_text ||= _("All Widgets")
    end

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    session["#{x_active_tree}_sortcol".to_sym] = @sortcol
    session["#{x_active_tree}_sortdir".to_sym] = @sortdir
  end

  private

  def widget_get_node_info
    @sb[:nodes] = x_node.split('-')
    if @sb[:nodes].length == 1
      get_all_widgets
      @right_cell_text = _("All %{models}") % {:models => ui_lookup(:models => "MiqWidget")}
      @right_cell_div  = "widget_list"
    elsif @sb[:nodes].length == 2
      # If a folder node is selected
      get_all_widgets(WIDGET_CONTENT_TYPE[@sb[:nodes][1]])
      @right_cell_div  = "widget_list"
      @right_cell_text = _("%{typ} %{model}") % {:typ => _(SINGULAR_WIDGET_TYPES[@sb[:nodes][1]]), :model => ui_lookup(:models => "MiqWidget")}
    else
      @record = @widget = MiqWidget.find_by_id(from_cid(@sb[:nodes].last))
      @widget_running = true if ["running", "queued"].include?(@widget.status.downcase)
      typ = WIDGET_CONTENT_TYPE.invert[@widget.content_type]
      content_type = _(SINGULAR_WIDGET_TYPES[typ])
      @right_cell_text = _("%{typ} %{model} \"%{name}\"") % {:typ => content_type, :name => @widget.title, :model => ui_lookup(:model => "MiqWidget")}
      @right_cell_div  = "widget_list"
      @sb[:wtype] = WIDGET_CONTENT_TYPE.invert[@widget.content_type]
      @sb[:col_order] = []
      rep = @widget.resource
      if rep && @widget.options && @widget.options[:col_order]
        @widget.options[:col_order].each do |c|
          rep.col_order.each_with_index do |col, idx|
            if col == c
              @sb[:col_order].push(rep.headers[idx]) unless @sb[:col_order].include?(rep.headers[idx])
            end
          end
        end
      end

      if @widget.visibility && @widget.visibility[:roles]
        @sb[:user_roles] = []
        if @widget.visibility[:roles][0] != "_ALL_"
          MiqUserRole.all.sort_by(&:name).each do |r|
            @sb[:user_roles].push(r.name) if @widget.visibility[:roles].include?(r.name)
          end
        end
      elsif @widget.visibility && @widget.visibility[:groups]
        @sb[:groups] = []
        MiqGroup.non_tenant_groups.sort_by(&:description).each do |r|
          @sb[:groups].push(r.description) if @widget.visibility[:groups].include?(r.description)
        end
      end
    end
  end

  # Common Widget button handler routines
  def process_widgets(widgets, task)
    process_elements(widgets, MiqWidget, task)
  end

  def widget_set_form_vars
    @timezone_abbr = get_timezone_abbr
    @edit = {}
    @edit[:widget_id] = @widget.id
    @edit[:read_only] = !!@widget.read_only

    # Remember how this edit started
    @edit[:type] = @widget.id ? "widget_edit" : "widget_new"
    if !@edit[:widget_id] && params[:pressed] != "widget_copy"
      @sb[:wtype] = @sb[:nodes][1]
    else
      @sb[:wtype] = WIDGET_CONTENT_TYPE.invert[@widget.content_type]
    end

    @edit[:key]               = @widget.id ? "widget_edit__#{@widget.id}" : "widget_edit__new"
    @edit[:new]               = {}
    @edit[:new][:title]       = @widget.title
    @edit[:new][:description] = @widget.description
    @edit[:new][:enabled]     = @widget.enabled
    @edit[:new][:roles] = []   # initializing incase of new widget since visibility is not set yet.
    @edit[:new][:groups] = []  # initializing incase of new widget since visibility is not set yet.

    @edit[:visibility_types] = [[_("<To All Users>"), "all"], [_("<By Role>"), "role"], [_("<By Group>"), "group"]]
    # Visibility Box
    if @widget.visibility
      if @widget.visibility[:roles]
        @edit[:new][:visibility_typ] = @widget.visibility[:roles][0] == "_ALL_" ? "all" : "role"
        if @widget.visibility[:roles][0] == "_ALL_"
          @edit[:new][:roles] = ["_ALL_"]
        else
          roles = MiqUserRole.where(:name => @widget.visibility[:roles])
          @edit[:new][:roles] = roles.collect { |role| to_cid(role.id) }.sort
        end
      elsif @widget.visibility[:groups]
        @edit[:new][:visibility_typ] = "group"
        groups = MiqGroup.where(:description => @widget.visibility[:groups])
        @edit[:new][:groups] = groups.collect { |group| to_cid(group.id) }.sort
      end
    end
    @edit[:sorted_user_roles] =
      MiqUserRole.all.sort_by { |r| r.name.downcase }
      .collect { |r| {r.name => to_cid(r.id)} }

    @edit[:sorted_groups] =
      MiqGroup.non_tenant_groups.sort_by { |g| g.description.downcase }
      .collect { |g| {g.description => to_cid(g.id)} }

    # Schedule Box - create new sched for copy/new, use existing for edit
    @edit[:schedule] = @widget.id && !@widget.miq_schedule.nil? ?
                          find_by_id_filtered(MiqSchedule, @widget.miq_schedule.id) :
                          MiqSchedule.new

    if @widget.resource_id && @widget.resource_type == "MiqReport"
      @edit[:schedule].name = @widget.resource.name
      @edit[:schedule].description = @widget.resource.title
      @edit[:rpt] = MiqReport.find_by_id(@widget.resource_id)
      @menu = get_reports_menu
      if @sb[:wtype] == "r"
        @menu.each do |m|
          m[1].each do |f|
            f.each do |r|
              if r.class != String
                r.each do |rep|
                  if rep == @edit[:rpt].name
                    @edit[:new][:filter] = m[0]
                    @edit[:new][:subfilter] = f[0]
                  end
                end
              end
            end
          end
        end
        report_selection_menus          # to build sub folders
      else
        widget_graph_menus      # to build report pulldown with only reports with grpahs
      end
      @edit[:new][:repfilter] = @edit[:rpt].id
    elsif ["r", "c"].include?(@sb[:wtype])
      @menu = get_reports_menu
      if @sb[:nodes][1] == "c"
        widget_graph_menus      # to build report pulldown with only reports with grpahs
      else
        report_selection_menus          # to build sub folders
      end
    elsif ["m"].include?(@sb[:wtype])
      @edit[:new][:shortcuts] = {}
      @widget.miq_widget_shortcuts.sort_by(&:sequence).each do |ws|
        @edit[:new][:shortcuts][ws.miq_shortcut.id] = ws.description
      end
      @edit[:new][:shortcut_keys] = @edit[:new][:shortcuts].keys  # Save the keys array so we can compare the hash order
      @edit[:avail_shortcuts] = widget_build_avail_shortcuts
    end
    @edit[:new][:timer] = ReportHelper::Timer.new
    if @edit[:schedule].run_at.nil? # New widget or schedule missing, default sched options
      @edit[:tz] = session[:user_tz]
      t = Time.now.in_time_zone(@edit[:tz]) + 1.day # Default date/time to tomorrow in selected time zone
      @edit[:new][:timer].typ = 'Hourly'
      @edit[:new][:timer].start_date = "#{t.month}/#{t.day}/#{t.year}"
    else
      sched = params[:action] == "widget_copy" ? @widget.miq_schedule : @edit[:schedule]
      @edit[:tz] = sched.run_at && sched.run_at[:tz] ? sched.run_at[:tz] : session[:user_tz]
      @edit[:new][:timer].update_from_miq_schedule(sched.run_at, @edit[:tz])
    end

    if @sb[:wtype] == "r"
      @pivot = @edit[:new][:pivot] = ReportController::PivotOptions.new
      rpt = @widget.resource_id && @widget.resource_type == "MiqReport" ? @widget.resource_id : nil
      widget_set_column_vars(rpt)
      @edit[:new][:pivot].by1 = @widget.options[:col_order][0] if @widget.options && @widget.options[:col_order] && @widget.options[:col_order][0]
      @edit[:new][:pivot].by2 = @widget.options[:col_order][1] if @widget.options && @widget.options[:col_order] && @widget.options[:col_order][1]
      @edit[:new][:pivot].by3 = @widget.options[:col_order][2] if @widget.options && @widget.options[:col_order] && @widget.options[:col_order][2]
      @edit[:new][:pivot].by4 = @widget.options[:col_order][3] if @widget.options && @widget.options[:col_order] && @widget.options[:col_order][3]
      @edit[:new][:pivot].options = @edit[:new][:fields].dup
      @edit[:new][:row_count] = @widget.row_count
    elsif @sb[:wtype] == "rf"
      @edit[:rss_feeds] = {}
      rss_feeds = RssFeed.all
      rss_feeds.each do |rf|
        @edit[:rss_feeds][rf.title] = rf.id
      end
      @edit[:new][:feed_type] = @widget.options && @widget.options[:url] ? "external" : "internal"
      if @widget.options && @widget.options[:url]
        RSS_FEEDS.each do |r|
          if r[1] == @widget.options[:url]
            @edit[:new][:url] = @widget.options[:url]
          end
        end
        @edit[:new][:txt_url] = @widget.options[:url] if @edit[:new][:url].blank?
      end
      @edit[:new][:row_count]   = @widget.row_count
      @edit[:new][:rss_feed_id] = @widget.resource_id         if @widget.resource_id && @widget.resource_type == "RssFeed"
    end
    @edit[:current] = copy_hash(@edit[:new])
  end

  def widget_build_avail_shortcuts
    as = MiqShortcut.order("sequence").collect { |s| [s.description, s.id] }
    @edit[:new][:shortcuts].each_key { |ns| as.delete_if { |a| a.last == ns } }
    as
  end

  def widget_set_column_vars(rpt)
    if rpt
      # Build group chooser arrays
      @edit[:rpt] = MiqReport.find(rpt)
      widget_build_selected_fields(@edit[:rpt])
    else
      @edit[:new][:fields] = []
    end
  end

  def widget_graph_menus
    @menu.each do |r|
      r[1].each do |subfolder, reps|
        subfolder.each_line do |s|
          @reps ||= []
          reps.each do |rep|
            temp_arr = []
            rec = MiqReport.find_by_name(rep.strip)
            if rec && rec.graph       # dont need to add rpt with no graph for widget editor, chart options box
              temp_arr.push("#{r[0]}/#{s}/#{rep}")
              temp_arr.push(rec.id)
              @reps.push(temp_arr) unless @reps.include?(temp_arr)
            end
          end
        end
      end
    end
  end

  # Build the fields array and headers hash from the rpt record cols and includes hashes
  def widget_build_selected_fields(rpt)
    fields = []
    rpt.col_order.each_with_index do |col, idx|
      field_key = col
      field_value = rpt.headers[idx]
      fields.push([field_value, field_key])               # Add to fields array
    end
    @edit[:new][:fields] = fields
  end

  # Build the main widgets tree
  def build_widgets_tree
    TreeBuilderReportWidgets.new('widgets_tree', 'widgets', @sb)
  end

  # Get variables from edit form
  def widget_get_form_vars
    @widget = @edit[:widget_id] ? MiqWidget.find_by_id(@edit[:widget_id]) : MiqWidget.new

    @edit[:new][:title]       = params[:title]            if params[:title]
    @edit[:new][:description] = params[:description]      if params[:description]
    @edit[:new][:enabled]     = (params[:enabled] == "1") if params[:enabled]
    @edit[:new][:filter]      = params[:filter_typ]       if params[:filter_typ]

    # report/chart/menu options box
    @edit[:new][:row_count] = @widget.row_count(params[:row_count]) if params[:row_count]
    if @sb[:wtype] == "r"
      if params[:filter_typ] || params[:subfilter_typ] || params[:repfilter_typ]
        # reset columns if report has changed
        @pivot = @edit[:new][:pivot] = ReportController::PivotOptions.new
      end
      @edit[:new][:subfilter] = params[:subfilter_typ] if params[:subfilter_typ]
      if params[:repfilter_typ] && params[:repfilter_typ] != "<Choose>"
        @edit[:rpt] = MiqReport.find(params[:repfilter_typ].to_i)
        @edit[:new][:repfilter] = @edit[:rpt].id
      elsif params[:repfilter_typ] && params[:repfilter_typ] == "<Choose>"
        @edit[:new][:repfilter] = nil
      end
      @edit[:new][:filter] = "" if @edit[:new][:filter] == "<Choose>"
      @edit[:new][:subfilter] = "" if @edit[:new][:subfilter] == "<Choose>"
    elsif @sb[:wtype] == "c"
      if params[:repfilter_typ] && params[:repfilter_typ] != "<Choose>"
        @edit[:rpt] = MiqReport.find(params[:repfilter_typ].to_i)
        @edit[:new][:repfilter] = @edit[:rpt].id
      end
      @edit[:new][:repfilter] = "" if params[:repfilter_typ] == "<Choose>"
    elsif @sb[:wtype] == "m"
      if params[:add_shortcut]
        s = MiqShortcut.find_by_id(params[:add_shortcut].to_i)
        @edit[:avail_shortcuts].delete_if { |as| as.last == s.id }
        @edit[:new][:shortcuts][s.id] = s.description
        @edit[:new][:shortcut_keys] = @edit[:new][:shortcuts].keys  # Save the keys array so we can compare the hash order
        @replace_filter_div = true
      end
      params.each do |k, v|
        if k.to_s.starts_with?("shortcut_desc_")
          sc_id = k.split("_").last.to_i
          @edit[:new][:shortcuts][sc_id] = v
        end
      end
    end

    # Schedule settings box
    @edit[:new][:timer] ||= ReportHelper::Timer.new
    @edit[:new][:timer].update_from_hash(params)

    if params[:time_zone]
      @edit[:tz] = params[:time_zone]
      @timezone_abbr = Time.now.in_time_zone(@edit[:tz]).strftime("%Z")
    end

    if @sb[:wtype] == "r"
      # Look at the pivot group field selectors
      @edit[:new][:pivot].update(params)

      if @edit[:new][:filter]
        @folders ||= []
        report_selection_menus          # to build sub folders
        rpt = @edit[:new][:repfilter] ? @edit[:new][:repfilter] : (@widget.resource_id && @widget.resource_type == "MiqReport" ? @widget.resource_id : nil)
        widget_set_column_vars(rpt)
      end
      @edit[:new][:pivot].options = @edit[:new][:fields].dup
      @pivot = @edit[:new][:pivot]
    elsif @sb[:wtype] == "c"
      widget_graph_menus      # to build report pulldown with only reports with grpahs
    elsif @sb[:wtype] == "rf"
      @edit[:new][:feed_type]   = params[:feed_type] if params[:feed_type]
      @edit[:new][:url]         = params[:rss_url]   if params[:rss_url]
      @edit[:new][:url]         = params[:txt_url]   if params[:txt_url]
      @edit[:new][:rss_feed_id] = params[:rss_feed]  if params[:rss_feed]
    end

    visibility_box_edit
  end

  # Set record variables to new values
  def widget_set_record_vars(widget)
    widget.title       = @edit[:new][:title]
    widget.description = @edit[:new][:description]
    widget.enabled     = @edit[:new][:enabled]
    widget.options ||= {}
    widget.options[:row_count] = widget.row_count(@edit[:new][:row_count]) if %w(r rf).include?(@sb[:wtype])
    #    if @sb[:wtype] == "m"
    #      widget.miq_shortcuts = @edit[:new][:shortcuts].keys.collect{|s| MiqShortcut.find_by_id(s)}
    #      ws = Array.new  # Create an array of widget shortcuts
    #      @edit[:new][:shortcuts].keys.each_with_index do |s_id, s_idx|
    #        sc = MiqShortcut.find_by_id(s_id)
    #        ws.push(MiqWidgetShortcut.new(:sequence=>s_idx, :description=>@edit[:new][:shortcuts][s_id], :miq_shortcut=>sc))
    #      end
    #      widget.miq_widget_shortcuts = ws
    #    end
    if @sb[:wtype] == "rf"
      widget.set_rss_properties(@edit[:new][:feed_type], @edit[:new][:rss_feed_id], @edit[:new][:url])
    else
      widget.resource = @edit[:rpt]
    end
    widget.options[:col_order] = [] if @edit[:new][:pivot]
    @edit[:new][:pivot] ||= ReportController::PivotOptions.new
    widget.options[:col_order].push(@edit[:new][:pivot].by1) if !@edit[:new][:pivot].by1.blank? && @edit[:new][:pivot].by1 != NOTHING_STRING
    widget.options[:col_order].push(@edit[:new][:pivot].by2) if !@edit[:new][:pivot].by2.blank? && @edit[:new][:pivot].by2 != NOTHING_STRING
    widget.options[:col_order].push(@edit[:new][:pivot].by3) if !@edit[:new][:pivot].by3.blank? && @edit[:new][:pivot].by3 != NOTHING_STRING
    widget.options[:col_order].push(@edit[:new][:pivot].by4) if !@edit[:new][:pivot].by4.blank? && @edit[:new][:pivot].by4 != NOTHING_STRING
    widget.content_type = WIDGET_CONTENT_TYPE[@sb[:wtype]]
    widget.visibility ||= {}
    if @edit[:new][:visibility_typ] == "group"
      groups = []
      @edit[:new][:groups].each do |g|
        group = MiqGroup.find_by_id(from_cid(g))
        groups.push(group.description) if from_cid(g) == group.id
      end
      widget.visibility[:groups] =  groups
      widget.visibility.delete(:roles) if widget.visibility[:roles]
    else
      if @edit[:new][:visibility_typ] == "role"
        roles = []
        @edit[:new][:roles].each do |r|
          role = MiqUserRole.find_by_id(from_cid(r))
          roles.push(role.name) if from_cid(r) == role.id
        end
        widget.visibility[:roles] =  roles
      else
        widget.visibility[:roles] = ["_ALL_"]
      end
      widget.visibility.delete(:groups) if widget.visibility[:groups]
    end

    # schedule settings
    @edit[:schedule].name         = widget.title
    @edit[:schedule].description  = widget.description
    @edit[:schedule].towhat       = "MiqWidget"
    @edit[:schedule].sched_action = {:method => "generate_widget"}
    @edit[:schedule].run_at = @edit[:new][:timer].flush_to_miq_schedule(@edit[:schedule].run_at, @edit[:tz])
    widget.miq_schedule = @edit[:schedule]
  end

  # Validate widget entries before updating record
  def widget_validate_entries
    if ["r", "c"].include?(@sb[:wtype]) && (!@edit[:new][:repfilter] || @edit[:new][:repfilter] == "")
      add_flash(_("A Report must be selected"), :error)
    end
    if %w(role group).include? @edit[:new][:visibility_typ]
      typ = @edit[:new][:visibility_typ]
      if @edit[:new][typ.pluralize.to_sym].blank?
        add_flash(_("A %{type} must be selected") % {:type => typ.titleize}, :error)
      end
    end
    if @sb[:wtype] == "r" && @edit[:new][:pivot].by1 == NOTHING_STRING
      add_flash(_("At least one Column must be selected"), :error)
    end
    if @sb[:wtype] == "m"
      if @edit[:new][:shortcuts].empty?
        add_flash(_("At least one Shortcut must be selected"), :error)
      else
        @edit[:new][:shortcuts].each do |s|
          if s.last.blank?
            add_flash(_("Shortcut description is required"), :error)
          end
        end
      end
    end
    @flash_array.nil?
  end
end
