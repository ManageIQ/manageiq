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
      new_ws = MiqWidgetShortcut.new(:sequence=>ws.sequence, :description=>ws.description, :miq_shortcut_id=>ws.miq_shortcut_id)
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
          add_flash(_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"MiqWidget"))
        else
          add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"MiqWidget"), :name=>@widget.name})
        end
        get_node_info
        @widget = nil
        @edit = session[:edit] = nil  # clean out the saved info
        replace_right_cell
      when "add","save"
        assert_privileges("widget_#{params[:id] ? "edit" : "new"}")
        id = params[:id] ? params[:id] : "new"
        return unless load_edit("widget_edit__#{id}","replace_cell__explorer")
        widget_get_form_vars
        widget = @edit[:widget_id] ? MiqWidget.find_by_id(@edit[:widget_id]) : MiqWidget.new  # get the current record
        widget_set_record_vars(widget)
        if widget_validate_entries && widget.save_with_shortcuts(@edit[:new][:shortcuts].to_a)
          AuditEvent.success(build_saved_audit(widget, @edit))
          add_flash(_("%{model} \"%{name}\" was saved") % {:model=>ui_lookup(:model=>"MiqWidget"), :name=>widget.title})
          params[:id] = @widget.id.to_s   # reset id in params for show
                                           # Build the filter expression and attach widget to schedule filter
          exp = Hash.new
          exp["="] = {"field"=>"MiqWidget.id", "value"=>@widget.id}
          @edit[:schedule].filter = MiqExpression.new(exp)
          @edit[:schedule].save
          @edit = session[:edit] = nil    # clean out the saved info
                                           #@schedule = nil
          replace_right_cell(:replace_trees => [:widgets])
        else
          widget.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          @changed = session[:changed] = (@edit[:new] != @edit[:current])
          render :update do |page|
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          end
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
    if params[:id] != nil && MiqWidget.find_by_id(params[:id]).nil?
      add_flash(_("%s no longer exists") % ui_lookup(:models=>"MiqWidget"),
                :error)
    else
      widgets.push(params[:id]) if params[:id]
    end
    w = MiqWidget.find_by_id(widgets[0])        #temp var to determine the parent node of deleted items
    process_widgets(widgets, "destroy") unless widgets.empty?
    unless flash_errors?
      if widgets.length > 1
        add_flash(_("The selected %s were deleted") % ui_lookup(:models=>"MiqWidget"),
                  :info, true)
      else
        add_flash(_("The selected %s was deleted") % ui_lookup(:model=>"MiqWidget"),
                  :info, true)
      end
    end
    nodes = x_node.split('-')
    self.x_node = "#{nodes[0]}-#{WIDGET_CONTENT_TYPE.invert[w.content_type]}"
    replace_right_cell(:replace_trees => [:widgets])
  end

  def widget_generate_content
    assert_privileges("widget_generate_content")
    w = MiqWidget.find_by_id(params[:id])
    begin
      w.queue_generate_content
    rescue StandardError => bang
      add_flash(_("Widget content generation error: ") << bang.message, :error)
    else
      add_flash(_("Content generation for this Widget has been initiated"))
    end
    #refresh widget show to update buttons
    widget_refresh
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def widget_form_field_changed
    return unless load_edit("widget_edit__#{params[:id]}","replace_cell__explorer")
    widget_get_form_vars
    render :update do |page|                    # Use JS to update the display

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
        page.replace("form_filter_div", :partial=>"widget_form_filter")
        page << "miqInitDashboardCols();"
      end

      if params[:visibility_typ]
        page.replace("form_role_visibility", :partial=>"layouts/role_visibility", :locals=>{:rec_id=>"#{@widget.id || "new"}", :action=>"widget_form_field_changed"})
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

  # Shortcut was dropped, reorder the :shortcuts hash
  def widget_shortcut_dd_done
    new_hash = Hash.new
    params[:col1].each{|sc| new_hash[sc.to_i] = @edit[:new][:shortcuts][sc.to_i]}
    @edit[:new][:shortcuts] = new_hash
    @edit[:new][:shortcut_keys] = @edit[:new][:shortcuts].keys  # Save the keys array so we can compare the hash order
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  # Shortcut was removed
  def widget_shortcut_remove
    return unless load_edit("widget_edit__#{params[:id]}","replace_cell__explorer")
    @widget = @edit[:widget_id] ? MiqWidget.find_by_id(@edit[:widget_id]) : MiqWidget.new
    @edit[:new][:shortcuts].delete(params[:shortcut].to_i)
    @edit[:new][:shortcut_keys] = @edit[:new][:shortcuts].keys  # Save the keys array so we can compare the hash order
    @edit[:avail_shortcuts] = widget_build_avail_shortcuts
    render :update do |page|                    # Use JS to update the display
      page.replace("form_filter_div", :partial=>"widget_form_filter")
      page << "miqInitDashboardCols();"
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  # Shortcut text reset
  def widget_shortcut_reset
    return unless load_edit("widget_edit__#{params[:id]}","replace_cell__explorer")
    @widget = @edit[:widget_id] ? MiqWidget.find_by_id(@edit[:widget_id]) : MiqWidget.new
    @edit[:new][:shortcuts][params[:shortcut].to_i] = MiqShortcut.find_by_id(params[:shortcut].to_i).description
    render :update do |page|                    # Use JS to update the display
      page.replace("form_filter_div", :partial=>"widget_form_filter")
      page << "miqInitDashboardCols();"
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  def get_all_widgets(nodeid=nil, rep_id=nil)
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
      #show all widgets
      @view, @pages = get_view(MiqWidget, :association=>"all")
    else
      # show only specific type
      if !rep_id
        @view, @pages = get_view(MiqWidget, :where_clause=>["content_type=?",nodeid])
      else
        #get all widgets for passed in report id
        #@view, @pages = get_view(MiqWidget, :where_clause=>["content_type=? AND resource_id=?",nodeid, rep_id])
        @temp[:widget_nodes] = MiqWidget.all(:conditions=>["content_type = ? AND resource_id = ?","report", rep_id])
      end
    end

    if x_active_tree == :widgets_tree
      # dont need to set these for report show screen
      @right_cell_div     = "widget_list"
      @right_cell_text  ||= _("All %s") % "MiqWidget"
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
      @right_cell_text = _("All %s") % ui_lookup(:models=>"MiqWidget")
      @right_cell_div  = "widget_list"
    elsif @sb[:nodes].length == 2
      # If a folder node is selected
      get_all_widgets(WIDGET_CONTENT_TYPE[@sb[:nodes][1]])
      @right_cell_div  = "widget_list"
      @right_cell_text = _("%{typ} %{model}") % {:typ=>WIDGET_TYPES[@sb[:nodes][1]].singularize, :model=>ui_lookup(:models=>"MiqWidget")}
    else
      @record = @widget = MiqWidget.find_by_id(from_cid(@sb[:nodes].last))
      @temp[:widget_running] = true if ["running","queued"].include?(@widget.status.downcase)
      typ = WIDGET_CONTENT_TYPE.invert[@widget.content_type]
      content_type = WIDGET_TYPES[typ].singularize
      @right_cell_text = _("%{typ} %{model} \"%{name}\"") % {:typ=>content_type, :name=>@widget.title, :model=>ui_lookup(:model=>"MiqWidget")}
      @right_cell_div  = "widget_list"
      @sb[:wtype] = WIDGET_CONTENT_TYPE.invert[@widget.content_type]
      @sb[:col_order] = Array.new
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
        @sb[:user_roles] = Array.new
        if @widget.visibility[:roles][0] != "_ALL_"
          MiqUserRole.all.sort{|a,b| a.name <=> b.name}.each do |r|
            @sb[:user_roles].push(r.name) if @widget.visibility[:roles].include?(r.name)
          end
        end
      elsif @widget.visibility && @widget.visibility[:groups]
        @sb[:groups] = Array.new
        MiqGroup.all.sort{|a,b| a.description <=> b.description}.each do |r|
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
    @timezone_abbr = get_timezone_abbr("server")
    @edit = Hash.new
    @edit[:widget_id] = @widget.id
    @edit[:read_only] = @widget.read_only ? true : false

    # Remember how this edit started
    @edit[:type] = @widget.id ? "widget_edit" : "widget_new"
    if !@edit[:widget_id] && params[:pressed] != "widget_copy"
      @sb[:wtype] = @sb[:nodes][1]
    else
      @sb[:wtype] = WIDGET_CONTENT_TYPE.invert[@widget.content_type]
    end

    @edit[:key]               = @widget.id  ? "widget_edit__#{@widget.id}" : "widget_edit__new"
    @edit[:new]               = Hash.new
    @edit[:new][:title]       = @widget.title
    @edit[:new][:description] = @widget.description
    @edit[:new][:enabled]     = @widget.enabled

    @edit[:visibility_types] = [["<To All Users>","all"],["<By Role>","role"],["<By Group>","group"]]
    #Visibility Box
    if @widget.visibility && @widget.visibility[:roles]
      @edit[:new][:visibility_typ] = @widget.visibility[:roles][0] == "_ALL_" ? "all" : "role"
      if @widget.visibility[:roles][0] == "_ALL_"
        @edit[:new][:roles] = ["_ALL_"]
      else
        @edit[:new][:roles] ||= Array.new
        @widget.visibility[:roles].each do |r|
          role = MiqUserRole.find_by_name(r)
          @edit[:new][:roles].push(to_cid(role.id)) if role
        end
      end
      @edit[:new][:roles].sort! unless @edit[:new][:roles].blank?
    elsif @widget.visibility && @widget.visibility[:groups]
      @edit[:new][:visibility_typ] = "group"
      @edit[:new][:groups] ||= Array.new
      @widget.visibility[:groups].each do |g|
        group = MiqGroup.find_by_description(g)
        @edit[:new][:groups].push(to_cid(group.id)) if group
      end
      @edit[:new][:groups].sort! unless @edit[:new][:groups].blank?
    end
    @edit[:new][:roles] ||= Array.new   # initializing incase of new widget since visibility is not set yet.
    @edit[:sorted_user_roles] = Array.new
    MiqUserRole.all.sort{|a,b| a.name.downcase <=> b.name.downcase}.each do |r|
      @edit[:sorted_user_roles].push(r.name=>to_cid(r.id))
    end

    @edit[:new][:groups] ||= Array.new    # initializing incase of new widget since visibility is not set yet.
    @edit[:sorted_groups] = Array.new
    MiqGroup.all.sort{|a,b| a.description.downcase <=> b.description.downcase}.each do |g|
      @edit[:sorted_groups].push(g.description=>to_cid(g.id))
    end

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
        @menu = get_reports_menu
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
        widget_graph_menus      #to build report pulldown with only reports with grpahs
      end
      @edit[:new][:repfilter] = @edit[:rpt].id
    elsif ["r","c"].include?(@sb[:wtype])
      @menu = get_reports_menu
      if @sb[:nodes][1] == "c"
        widget_graph_menus      #to build report pulldown with only reports with grpahs
      else
        report_selection_menus          # to build sub folders
      end
    elsif ["m"].include?(@sb[:wtype])
      @edit[:new][:shortcuts] = Hash.new
      @widget.miq_widget_shortcuts.sort{|a,b| a.sequence <=> b.sequence}.each{|ws| @edit[:new][:shortcuts][ws.miq_shortcut.id] = ws.description}
      @edit[:new][:shortcut_keys] = @edit[:new][:shortcuts].keys  # Save the keys array so we can compare the hash order
      @edit[:avail_shortcuts] = widget_build_avail_shortcuts
    end
    @edit[:new][:timer_weeks ] = "1"
    @edit[:new][:timer_days] = "1"
    @edit[:new][:timer_hours] = "1"
    if @edit[:schedule].run_at.nil? # New widget or schedule missing, default sched options
      @edit[:tz] = session[:user_tz]
      t = Time.now.in_time_zone(@edit[:tz]) + 1.day # Default date/time to tomorrow in selected time zone
      @edit[:new][:timer_typ] = "Hourly"
      @edit[:new][:start_hour] = "00"
      @edit[:new][:start_min] = "00"
    else
      sched = params[:action] == "widget_copy" ? @widget.miq_schedule : @edit[:schedule]
      @edit[:new][:timer_typ] = sched.run_at[:interval][:unit].titleize
      @edit[:new][:timer_months] = sched.run_at[:interval][:value] if sched.run_at[:interval][:unit] == "monthly"
      @edit[:new][:timer_weeks] = sched.run_at[:interval][:value] if sched.run_at[:interval][:unit] == "weekly"
      @edit[:new][:timer_days] = sched.run_at[:interval][:value] if sched.run_at[:interval][:unit] == "daily"
      @edit[:new][:timer_hours] = sched.run_at[:interval][:value] if sched.run_at[:interval][:unit] == "hourly"
      @edit[:tz] = sched.run_at && sched.run_at[:tz] ? sched.run_at[:tz] : session[:user_tz]
      t = sched.run_at[:start_time].to_time.in_time_zone(@edit[:tz])
      @edit[:new][:start_hour] = t.strftime("%H")
      @edit[:new][:start_min] = t.strftime("%M")
    end
    @edit[:new][:start_date] = "#{t.month}/#{t.day}/#{t.year}"  # Set the start date

    if @sb[:wtype] == "r"
      @pivotby1 = @edit[:new][:pivotby1] = NOTHING_STRING # Initialize groupby fields to nothing
      @pivotby2 = @edit[:new][:pivotby2] = NOTHING_STRING
      @pivotby3 = @edit[:new][:pivotby3] = NOTHING_STRING
      @pivotby4 = @edit[:new][:pivotby4] = NOTHING_STRING
      rpt = @widget.resource_id && @widget.resource_type == "MiqReport" ? @widget.resource_id : nil
      widget_set_column_vars(rpt)
      @pivotby1 = @edit[:new][:pivotby1] = @widget.options[:col_order][0] if @widget.options && @widget.options[:col_order] && @widget.options[:col_order][0]
      @pivotby2 = @edit[:new][:pivotby2] = @widget.options[:col_order][1] if @widget.options && @widget.options[:col_order] && @widget.options[:col_order][1]
      @pivotby3 = @edit[:new][:pivotby3] = @widget.options[:col_order][2] if @widget.options && @widget.options[:col_order] && @widget.options[:col_order][2]
      @pivotby4 = @edit[:new][:pivotby4] = @widget.options[:col_order][3] if @widget.options && @widget.options[:col_order] && @widget.options[:col_order][3]
      @pivots1  = @edit[:new][:fields].dup
      @pivots2  = @pivots1.dup.delete_if { |g| g[1] == @edit[:new][:pivotby1] }
      @pivots3  = @pivots2.dup.delete_if { |g| g[1] == @edit[:new][:pivotby2] }
      @pivots4  = @pivots3.dup.delete_if { |g| g[1] == @edit[:new][:pivotby3] }
      @edit[:new][:row_count] = @widget.options[:row_count] if @widget.options && @widget.options[:row_count]
    elsif @sb[:wtype] == "rf"
      @edit[:rss_feeds] = Hash.new
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
      @edit[:new][:row_count]   = @widget.options[:row_count] if @widget.options     && @widget.options[:row_count]
      @edit[:new][:rss_feed_id] = @widget.resource_id         if @widget.resource_id && @widget.resource_type == "RssFeed"
    end
    @edit[:current] = copy_hash(@edit[:new])
  end

  def widget_build_avail_shortcuts
    as = MiqShortcut.order("sequence").collect{|s| [s.description, s.id]}
    @edit[:new][:shortcuts].each_key{|ns| as.delete_if{|a| a.last == ns} }
    return as
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
      r[1].each do |subfolder,reps|
        subfolder.each_line do |s|
          @reps ||= Array.new
          reps.each do |rep|
            temp_arr = Array.new
            rec = MiqReport.find_by_name(rep.strip)
            if rec && rec.graph       # dont need to add rpt with no graph for widget editor, chart options box
              temp_arr.push("#{r[0]}/#{s}/#{rep}")
              temp_arr.push(rec.id)
              @reps.push(temp_arr) if !@reps.include?(temp_arr)
            end
          end
        end
      end
    end
  end

  # Build the fields array and headers hash from the rpt record cols and includes hashes
  def widget_build_selected_fields(rpt)
    fields = Array.new
    rpt.col_order.each_with_index do |col, idx|
      field_key = col
      field_value = rpt.headers[idx]
      fields.push([field_value, field_key])               # Add to fields array
    end
    @edit[:new][:fields] = fields
  end

  #Build the main widgets tree
  def build_widgets_tree(type=:widgets, name=:widgets_tree)
    x_tree_init(name, type, 'MiqWidget', :full_ids => true)
    tree_nodes = x_build_dynatree(x_tree(name))

    region = MiqRegion.my_region
    # Fill in root node details
    root           = tree_nodes.first
    root[:title]   = "All Widgets"
    root[:tooltip] = "All Widgets"
    root[:icon]    = "folder.png"
    @temp[name]    = tree_nodes.to_json          # JSON object for tree loading
    x_node_set(tree_nodes.first[:key], name) unless x_node(name)  # Set active node to root if not set
  end

  # Add the children of a node that is being expanded (autoloaded), called by generic tree_autoload method
  def tree_add_child_nodes(id)
    x_get_child_nodes_dynatree(x_active_tree, id)
  end

  # Get variables from edit form
  def widget_get_form_vars
    @widget = @edit[:widget_id] ? MiqWidget.find_by_id(@edit[:widget_id]) : MiqWidget.new

    @edit[:new][:title]       = params[:title]            if params[:title]
    @edit[:new][:description] = params[:description]      if params[:description]
    @edit[:new][:enabled]     = (params[:enabled] == "1") if params[:enabled]
    @edit[:new][:filter]      = params[:filter_typ]       if params[:filter_typ]

    # report/chart/menu options box
    @edit[:new][:row_count] = params[:row_count] if params[:row_count]
    if @sb[:wtype] == "r"
      if params[:filter_typ] || params[:subfilter_typ] || params[:repfilter_typ]
        #reset columns if report has changed
        @edit[:new][:pivotby1] = NOTHING_STRING
        @edit[:new][:pivotby2] = NOTHING_STRING
        @edit[:new][:pivotby3] = NOTHING_STRING
        @edit[:new][:pivotby4] = NOTHING_STRING
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
        @edit[:avail_shortcuts].delete_if{|as| as.last == s.id}
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

    #Schedule settings box
    @edit[:new][:timer_typ]    = params[:timer_typ]    if params[:timer_typ]
    @edit[:new][:timer_months] = params[:timer_months] if params[:timer_months]
    @edit[:new][:timer_weeks]  = params[:timer_weeks]  if params[:timer_weeks]
    @edit[:new][:timer_days]   = params[:timer_days]   if params[:timer_days]
    @edit[:new][:timer_hours]  = params[:timer_hours]  if params[:timer_hours]
    @edit[:new][:start_date]   = params[:miq_date_1]   if params[:miq_date_1]
    @edit[:new][:start_hour]   = params[:start_hour]   if params[:start_hour]
    @edit[:new][:start_min]    = params[:start_min]    if params[:start_min]

    if params[:time_zone]
      @edit[:tz] = params[:time_zone]
      @timezone_abbr = Time.now.in_time_zone(@edit[:tz]).strftime("%Z")
      t = Time.now.in_time_zone(@edit[:tz]) + 1.day # Default date/time to tomorrow in selected time zone
      @edit[:new][:start_date] = "#{t.month}/#{t.day}/#{t.year}"  # Reset the start date
      @edit[:new][:start_hour] = "00" # Reset time to midnight
      @edit[:new][:start_min] = "00"
    end

    if @sb[:wtype] == "r"
      # Look at the pivot group field selectors
      if params[:chosen_pivot1] && params[:chosen_pivot1] != @edit[:new][:pivotby1]
        @edit[:new][:pivotby1] = params[:chosen_pivot1]
        if params[:chosen_pivot1] == NOTHING_STRING
          @edit[:new][:pivotby2] = NOTHING_STRING
          @edit[:new][:pivotby3] = NOTHING_STRING
          @edit[:new][:pivotby4] = NOTHING_STRING
        elsif params[:chosen_pivot1] == @edit[:new][:pivotby2]
          @edit[:new][:pivotby2] = @edit[:new][:pivotby3]
          @edit[:new][:pivotby3] = @edit[:new][:pivotby4]
          @edit[:new][:pivotby4] = NOTHING_STRING
        elsif params[:chosen_pivot1] == @edit[:new][:pivotby3]
          @edit[:new][:pivotby3] = @edit[:new][:pivotby4]
          @edit[:new][:pivotby4] = NOTHING_STRING
        end
      elsif params[:chosen_pivot2] && params[:chosen_pivot2] != @edit[:new][:pivotby2]
        @edit[:new][:pivotby2] = params[:chosen_pivot2]
        if params[:chosen_pivot2] == NOTHING_STRING
          @edit[:new][:pivotby3] = NOTHING_STRING
          @edit[:new][:pivotby4] = NOTHING_STRING
        elsif params[:chosen_pivot2] == @edit[:new][:pivotby3]
          @edit[:new][:pivotby3] = @edit[:new][:pivotby4]
          @edit[:new][:pivotby4] = NOTHING_STRING
        elsif params[:chosen_pivot2] == @edit[:new][:pivotby4]
          @edit[:new][:pivotby4] = NOTHING_STRING
        end
      elsif params[:chosen_pivot3] && params[:chosen_pivot3] != @edit[:new][:pivotby3]
        @edit[:new][:pivotby3] = params[:chosen_pivot3]
        if params[:chosen_pivot3] == NOTHING_STRING || params[:chosen_pivot3] == @edit[:new][:pivotby4]
          @edit[:new][:pivotby4] = NOTHING_STRING
        end
      elsif params[:chosen_pivot4] && params[:chosen_pivot4] != @edit[:new][:pivotby4]
        @edit[:new][:pivotby4] = params[:chosen_pivot4]
      end
      if @edit[:new][:filter]
        @folders ||= Array.new
        report_selection_menus          # to build sub folders
        rpt = @edit[:new][:repfilter] ? @edit[:new][:repfilter] : (@widget.resource_id && @widget.resource_type == "MiqReport" ? @widget.resource_id : nil)
        widget_set_column_vars(rpt)
      end
      @pivots1  = @edit[:new][:fields].dup
      @pivots2  = @pivots1.dup.delete_if{|g| g[1] == @edit[:new][:pivotby1]}
      @pivots3  = @pivots2.dup.delete_if{|g| g[1] == @edit[:new][:pivotby2]}
      @pivots4  = @pivots3.dup.delete_if{|g| g[1] == @edit[:new][:pivotby3]}
      @pivotby1 = @edit[:new][:pivotby1]
      @pivotby2 = @edit[:new][:pivotby2]
      @pivotby3 = @edit[:new][:pivotby3]
      @pivotby4 = @edit[:new][:pivotby4]
    elsif @sb[:wtype] == "c"
      widget_graph_menus      #to build report pulldown with only reports with grpahs
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
    widget.options   ||= Hash.new
    if ["r", "rf"].include?(@sb[:wtype])
      widget.options[:row_count] = @edit[:new][:row_count].blank? ? 5 : @edit[:new][:row_count].to_i
    end
#    if @sb[:wtype] == "m"
#      widget.miq_shortcuts = @edit[:new][:shortcuts].keys.collect{|s| MiqShortcut.find_by_id(s)}
#      ws = Array.new  # Create an array of widget shortcuts
#      @edit[:new][:shortcuts].keys.each_with_index do |s_id, s_idx|
#        sc = MiqShortcut.find_by_id(s_id)
#        ws.push(MiqWidgetShortcut.new(:sequence=>s_idx, :description=>@edit[:new][:shortcuts][s_id], :miq_shortcut=>sc))
#      end
#      widget.miq_widget_shortcuts = ws
#    end
    widget.options[:url] = @edit[:new][:url] if !@edit[:new][:url].blank?
    widget.options[:col_order] = Array.new if @edit[:new][:pivotby1]
    widget.options[:col_order].push(@edit[:new][:pivotby1]) if !@edit[:new][:pivotby1].blank? && @edit[:new][:pivotby1] != "<<< Nothing >>>"
    widget.options[:col_order].push(@edit[:new][:pivotby2]) if !@edit[:new][:pivotby2].blank? && @edit[:new][:pivotby2] != "<<< Nothing >>>"
    widget.options[:col_order].push(@edit[:new][:pivotby3]) if !@edit[:new][:pivotby3].blank? && @edit[:new][:pivotby3] != "<<< Nothing >>>"
    widget.options[:col_order].push(@edit[:new][:pivotby4]) if !@edit[:new][:pivotby4].blank? && @edit[:new][:pivotby4] != "<<< Nothing >>>"
    widget.content_type = WIDGET_CONTENT_TYPE[@sb[:wtype]]
    widget.visibility ||= Hash.new
    if @edit[:new][:visibility_typ] == "group"
      groups = Array.new
      @edit[:new][:groups].each do |g|
        group = MiqGroup.find_by_id(from_cid(g))
        groups.push(group.description) if from_cid(g) == group.id
      end
      widget.visibility[:groups] =  groups
      widget.visibility.delete(:roles) if widget.visibility[:roles]
    else
      if @edit[:new][:visibility_typ] == "role"
        roles = Array.new
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
    if @edit[:new][:rss_feed_id]
      widget.resource = RssFeed.find(@edit[:new][:rss_feed_id])
    else
      widget.resource = @edit[:rpt]
    end

    #schedule settings
    @edit[:schedule].name         = widget.title
    @edit[:schedule].description  = widget.description
    @edit[:schedule].towhat       = "MiqWidget"
    @edit[:schedule].sched_action = { :method=>"generate_widget"}
    @edit[:schedule].run_at     ||= Hash.new
    run_at = create_time_in_utc("#{@edit[:new][:start_date]} #{@edit[:new][:start_hour]}:#{@edit[:new][:start_min]}:00", @edit[:tz])
    @edit[:schedule].run_at[:start_time] = "#{run_at} Z"
    @edit[:schedule].run_at[:tz]         = @edit[:tz]
    @edit[:schedule].run_at[:interval] ||= Hash.new
    @edit[:schedule].run_at[:interval][:unit] = @edit[:new][:timer_typ].downcase
    case @edit[:new][:timer_typ].downcase
    when "monthly"
      @edit[:schedule].run_at[:interval][:value] = @edit[:new][:timer_months]
    when "weekly"
      @edit[:schedule].run_at[:interval][:value] = @edit[:new][:timer_weeks]
    when "daily"
      @edit[:schedule].run_at[:interval][:value] = @edit[:new][:timer_days]
    when "hourly"
      @edit[:schedule].run_at[:interval][:value] = @edit[:new][:timer_hours]
    else
      @edit[:schedule].run_at[:interval].delete(:value)
    end
    widget.miq_schedule = @edit[:schedule]
  end

  # Validate widget entries before updating record
  def widget_validate_entries
    if ["r", "c"].include?(@sb[:wtype]) && (!@edit[:new][:repfilter] || @edit[:new][:repfilter] == "")
      add_flash(_("%s must be selected") % "A Report", :error)
    end
    if @sb[:wtype] == "rf" && @edit[:new][:visibility_typ] == "role" && @edit[:new][:roles].blank?
      add_flash(_("%s must be selected") % "A Role", :error)
    end
    if @sb[:wtype] == "r" && @edit[:new][:pivotby1] == "<<< Nothing >>>"
      add_flash(_("%s must be selected") % "At least one Column", :error)
    end
    if @sb[:wtype] == "m"
      if @edit[:new][:shortcuts].empty?
        add_flash(_("%s must be selected") % "At least one Shortcut", :error)
      else
        @edit[:new][:shortcuts].each do |s|
          if s.last.blank?
            add_flash(_("%s is required") % "Shortcut description", :error)
          end
        end
      end
    end
    return @flash_array.nil?
  end
end
