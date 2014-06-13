module ReportController::Reports
  extend ActiveSupport::Concern

  include_concern 'Editor'

  def show_report
    self.x_active_tree = :reports_tree
    unless params[:task_id]                       # First time thru, kick off the report generate task
      @parent_report = MiqReport.find(params[:id])
      initiate_wait_for_task(:task_id => @parent_report.async_generate_table(
        :userid     => session[:userid],
        :session_id => request.session_options[:id],
        :mode       => "adhoc"))
      return
    end
    miq_task              = MiqTask.find(params[:task_id])      # Not first time, read the task record
    session[:rpt_id]      = params[:id]
    session[:rpt_task_id] = params[:task_id]
    session[:rpt_count]   = nil
    build_report_listnav
    @report_result_id = MiqReportResult.find_by_miq_task_id(session[:rpt_task_id]).id       #need to save this for download buttons
    if miq_task.task_results.blank? || miq_task.status != "Ok"  # Check to see if any results came back or status not Ok
      add_flash(I18n.t("flash.report.generation_error",
                      :status=>miq_task.status, :message=>miq_task.message),
                :error)
      title = MiqReport.find(session[:rpt_id]).name
    else
      @html = report_first_page(miq_task.miq_report_result) # Get the first page of the results
      unless @report.graph.blank?
        @zgraph   = true
        @ght_type = "hybrid"
      else
        @ght_type = "tabular"
      end
      title = @report.name
    end
    render :update do |page|                      # Use JS to update the display
      page.replace_html("report_list_div", :partial=>"report_list")
      page << "reports_tree.saveOpenStates('reports_tree','path=/');"
      page << "reports_tree.selectItem('#{x_node(:reports_tree)}');"
      cell_text = I18n.t("cell_header.model_record",
                        :name=>title,
                        :model=>ui_lookup(:model=>"MiqReport"))
      page << "dhxLayout.cells('b').setText(\'#{j_str(cell_text)}\');"
      page << "miqSparkle(false);"
    end
  end

  def miq_report_run
    assert_privileges("miq_report_run")
    self.x_active_tree = :reports_tree
    @sb[:active_tab] = "saved_reports"
    rep = MiqReport.find(params[:id])
    rep.queue_generate_table(:userid => session[:userid])
    title = rep.name
    nodes = x_node.split('-')
    get_all_reps(nodes[4])
    @sb[:selected_rep_id] = from_cid(nodes[3].split('_').last)
    if role_allows(:feature=>"miq_report_widget_editor")
      # all widgets for this report
      get_all_widgets("report",from_cid(nodes[3].split('_').last))
    end
    add_flash(I18n.t("flash.report.queued"))
    replace_right_cell(:replace_trees => [:reports,:savedreports])
  end

  def miq_report_save
    rr               = MiqReportResult.find(@sb[:pages][:rr_id])
    rr.save_for_user(session[:userid])                # Save the current report results for this user
    @_params[:sortby] = "last_run_on"
    view, pages = get_view(MiqReportResult, :where_clause=>set_saved_reports_condition(@sb[:miq_report_id]))
    savedreports = view.table.data
    r = savedreports.first
    @right_cell_div  = "report_list"
    @right_cell_text ||= I18n.t("cell_header.model_record",
                              :name=>r.name,
                              :model=>"Saved Report")
    add_flash(I18n.t("flash.edit.saved",
                    :model=>ui_lookup(:model=>"MiqReport"),
                    :name=>r.name))
    @sb[:rep_tree_build_time] = Time.now.utc
    replace_right_cell(:replace_trees => [:reports,:savedreports])
  end

  def show_preview
    unless params[:task_id]                       # First time thru, kick off the report generate task
      @rpt = create_report_object                 # Build a report object from the latest edit fields
      initiate_wait_for_task(:task_id => @rpt.async_generate_table(
        :userid     => session[:userid],
        :session_id => request.session_options[:id],
        :limit      => 50,
        :mode       => "adhoc"))
      return
    end
    miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
    rpt = miq_task.task_results
    if miq_task.task_results.blank? || miq_task.status != "Ok"  # Check to see if any results came back or status not Ok
      add_flash(I18n.t("flash.report.preview_error",
                      :status=>miq_task.status, :message=>miq_task.message),
                :error)
    else
      rr = miq_task.miq_report_result
      @html = report_build_html_table(rr.report, rr.html_rows(:page=>1, :per_page=>100).join)

      if rpt.timeline                   # If timeline present
        @timeline                 = true
        rpt.extras[:browser_name] = browser_info("name").downcase
        #flag to force formatter to build timeline in xml for preview screen
        rpt.extras[:tl_preview] = true
        @edit[:tl_xml]            = rpt.to_timeline
        @edit[:tl_position]       = format_timezone(rpt.extras[:tl_position],Time.zone,"tl")
      else
        @edit[:tl_xml]            = nil
      end
      unless rpt.graph.nil? || rpt.graph[:type].blank?            # If graph present
        # FIXME: UNTESTED!!!
        rpt.to_chart(@settings[:display][:reporttheme], false, MiqReport.graph_options(350, 250))  # Generate the chart
        @edit[:zgraph_xml] = rpt.chart                 # Save chart data
      else
        @edit[:zgraph_xml] = nil
      end
    end
    miq_task.destroy
    render :update do |page|                      # Use JS to update the display
      page.replace_html("form_preview", :partial=>"form_preview")
      page << "miqSparkle(false);"
    end
  end

  def miq_report_delete
    assert_privileges("miq_report_delete")
    rpt = MiqReport.find(params[:id])
    report_widgets = MiqWidget.all(:conditions => {:resource_id => rpt.id})
    if report_widgets.length > 0
      add_flash(I18n.t("flash.report.has_widgets_cant_delete"), :error)
      render :update do |page|
        page.replace("flash_msg_div_report_list", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_report_list"})
      end
    else
      begin
        if rpt.rpt_type == "Default"
          add_flash(I18n.t("flash.cant_delete_default", :model=>ui_lookup(:model=>"MiqReport"), :name=>rpt.name), :error)
          redirect_to :action=>"editreport", :id=>rpt.id, :flash_msg=>flash, :flash_error=>true
          return
        end
        rpt_name = rpt.name
        audit = {:event=>"report_record_delete", :message=>"[#{rpt_name}] Record deleted", :target_id=>rpt.id, :target_class=>"MiqReport", :userid => session[:userid]}
        rpt.destroy
      rescue StandardError => bang
        add_flash(I18n.t("flash.record.error_during_task", :model=>ui_lookup(:model=>"MiqReport"), :name=>rpt_name, :task=>task) << bang.message, :error)
        render :update do |page|
          page.replace("flash_msg_div_report_list", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_report_list"})
        end
      else
        AuditEvent.success(audit)
        add_flash(I18n.t("flash.record.deleted",
                        :model=>ui_lookup(:model=>"MiqReport"),
                        :name=>rpt_name))
      end
      params[:id] = nil
      @sb[:rep_tree_build_time] = Time.now.utc
      nodes = x_node.split('_')
      self.x_node = "#{nodes[0]}_#{nodes[1]}"
      replace_right_cell(:replace_trees => [:reports])
    end
  end

  def download_report
    assert_privileges("miq_report_export")
    @yaml_string = MiqReport.export_to_yaml(params[:id] ? [params[:id]] : @sb[:choices_chosen], MiqReport)
    file_name    = "Reports_#{format_timezone(Time.now,Time.zone,"export_filename")}.yaml"
    disable_client_cache
    send_data(@yaml_string, :filename => file_name )
  end

  # Generating sample chart
  def sample_chart
    render Charting.render_format => Charting.sample_chart(@edit[:new], @settings[:display][:reporttheme])
  end

  def sample_timeline
    tl_xml = MiqXml.load("<data/>")
    tl_event(tl_xml, format_timezone(Time.now, "UTC", nil), "Now", "red")
    tl_event(tl_xml, format_timezone(Time.now - 5.seconds, "UTC", nil), "5 Seconds Ago")
    tl_event(tl_xml, format_timezone(Time.now - 1.minute, "UTC", nil), "1 Minute Ago")
    tl_event(tl_xml, format_timezone(Time.now - 5.minutes, "UTC", nil), "5 Minutes Ago")
    tl_event(tl_xml, format_timezone(Time.now - 1.hour, "UTC", nil), "1 Hour Ago")
    tl_event(tl_xml, format_timezone(Time.now - 1.day, "UTC", nil), "Yesterday")
    tl_event(tl_xml, format_timezone(Time.now - 1.week, "UTC", nil), "Last Week")
    tl_event(tl_xml, format_timezone(Time.now - 1.month, "UTC", nil), "Last Month")
    tl_event(tl_xml, format_timezone(Time.now - 3.months, "UTC", nil), "3 Months Ago")
    tl_event(tl_xml, format_timezone(Time.now - 1.year, "UTC", nil), "Last Year")
    render :xml=>tl_xml.to_s
  end

  def preview_timeline
    render :xml => session[:edit][:tl_xml]
    session[:edit][:tl_xml] = nil
  end

  # Send ZiYa graph XML stream to the client
  def preview_chart
    render Charting.render_format => session[:edit][:zgraph_xml]
    session[:edit][:zgraph_xml] = nil
  end

  #get saved reports for a specific report
  def get_all_reps(nodeid=nil)
    #set nodeid from @sb, incase sort was pressed
    nodeid = x_active_tree == :reports_tree ?
        x_node.split('-').last :
        x_node.split('-').last.split('_')[0] if nodeid.nil?
    @sb[:miq_report_id] = from_cid(nodeid)
    @record = @miq_report = MiqReport.find(@sb[:miq_report_id])
    if @sb[:active_tab] == "saved_reports" || x_active_tree == :savedreports_tree
      @force_no_grid_xml   = true
      @gtl_type            = "list"
      @ajax_paging_buttons = true
      @no_checkboxes = false

      if params[:ppsetting]                                             # User selected new per page value
        @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
        @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
      end

      @sortcol = session["#{x_active_tree}_sortcol".to_sym].nil? ? 0 : session["#{x_active_tree}_sortcol".to_sym].to_i
      @sortdir = session["#{x_active_tree}_sortdir".to_sym].nil? ? "DESC" : session["#{x_active_tree}_sortdir".to_sym]

      #don't need paging on report show screen for available reports box
      #@view, @pages = get_view(MiqReportResult, :where_clause=>set_saved_reports_condition(from_cid(nodeid.split('_')[0])), :all_pages=>x_active_tree == :reports_tree ? true : false)
      @view, @pages = get_view(MiqReportResult, :where_clause=>set_saved_reports_condition(from_cid(nodeid.split('_')[0])))
      @sb[:timezone_abbr] = @timezone_abbr if @timezone_abbr
      #Saving converted time to be displayed on saved reports list view
      @view.table.data.each_with_index do |s,s_idx|
        @temp[:report_running] = true if s.status.downcase == "running" || s.status.downcase == "queued"
      end

      @current_page = @pages[:current] unless @pages.nil? # save the current page number
      session["#{x_active_tree}_sortcol".to_sym] = @sortcol
      session["#{x_active_tree}_sortdir".to_sym] = @sortdir
    end

    if @sb[:active_tab] == "report_info"
      if session[:userrole] == "super_administrator"  # Super admins see all report schedules
        schedules = MiqSchedule.all(:conditions=>["towhat=?", "MiqReport"])
      else
        schedules = MiqSchedule.all(:conditions=>["towhat=? AND userid=?", "MiqReport", session[:userid]])
      end
      @temp[:schedules] = Array.new
      schedules.sort { |a,b| a.name <=> b.name }.each do |s|
        if s.filter.exp["="]["value"].to_i == @miq_report.id.to_i
         @temp[:schedules].push(s)
        end
      end

      @temp[:widget_nodes] = MiqWidget.all(:conditions=>["resource_id = ?", @miq_report.id.to_i])
    end

    @sb[:tree_typ]   = "reports"
    @right_cell_text = I18n.t("cell_header.model_record",
                              :name=>@miq_report.name,
                              :model=>ui_lookup(:model=>"MiqReport"))
  end

  # Show the current report in text format
  def show_text
    @text = @report.to_text(100)
    render :partial=>"reports"
  end

  # Show the current report in csv format
  def show_csv
    @csv = @report.to_csv
    render :partial=>"reports"
  end

  # Show the current report in pdf format
  def show_pdf
    @pdf = @report.to_pdf
    render :partial=>"reports"
  end

  def rep_change_tab
    @sb[:active_tab] = params[:tab_id]
    replace_right_cell
  end

  private

  def tl_event(tl, tl_time, tl_text, tl_color = nil)
      event = tl.root.add_element("event", {
          "start"=>tl_time,
          #                                       "end" => Time.now,
          #                                       "isDuration" => "true",
          "title"=>tl_text,
#         "icon"=>"/images/icons/16/16-event-vm_snapshot.png",
          "icon"=>"/images/icons/16/blue-circle.png",
#         "image"=>"/images/icons/64/64-snapshot.png",
          "color"=>tl_color
          #"image"=>"/images/icons/64/64-vendor-#{vm.vendor.downcase}.png"
        })
      event.text = tl_text
  end

  # Check for valid report configuration in @edit[:new]
  def valid_report?(rpt)

    if @edit[:new][:model] == TREND_MODEL
      unless @edit[:new][:perf_trend_col]
        add_flash(I18n.t("flash.edit.field_required", :field=>"Trending for"), :error)
        @sb[:miq_tab] = "new_1"
      end
      unless @edit[:new][:perf_limit_col] || @edit[:new][:perf_limit_val]
        add_flash(I18n.t("flash.edit.field_must_be.configured", :field=>"Trend Target Limit"), :error)
        @sb[:miq_tab] = "new_1"
      end
      if @edit[:new][:perf_limit_val] && !is_numeric?(@edit[:new][:perf_limit_val])
        add_flash(I18n.t("flash.edit.field_must_be.numeric", :field=>"Trend Target Limit"), :error)
        @sb[:miq_tab] = "new_1"
      end
    else
      if @edit[:new][:fields].length == 0
        add_flash(I18n.t("flash.edit.at_least_1.selected", :field=>"Field"), :error)
        @sb[:miq_tab] = "new_1"
      end
    end

    if @edit[:new][:model] == "Chargeback"
      unless @edit[:new][:cb_show_typ]
        add_flash(I18n.t("flash.edit.select_required", :selection=>"Show Costs by"), :error)
        @sb[:miq_tab] = "new_3"
      else
        if @edit[:new][:cb_show_typ] == "owner"
          unless @edit[:new][:cb_owner_id]
            add_flash(I18n.t("flash.edit.select_required", :selection=>"An Owner"), :error)
            @sb[:miq_tab] = "new_3"
          end
        elsif @edit[:new][:cb_show_typ] == "tag"
          unless @edit[:new][:cb_tag_cat]
            add_flash(I18n.t("flash.edit.select_required", :selection=>"A Tag Category"), :error)
            @sb[:miq_tab] = "new_3"
          else
            unless @edit[:new][:cb_tag_value]
              add_flash(I18n.t("flash.edit.select_required", :selection=>"A Tag"), :error)
              @sb[:miq_tab] = "new_3"
            end
          end
        end
      end
    end

    # Validate column styles
    unless rpt.col_options.blank? || @edit[:new][:field_order].nil?
      @edit[:new][:field_order].each do |f| # Go thru all of the cols in order
        col = f.last.split(".").last.split("-").last
        if val = rpt.col_options[col] # Skip if no options for this col
          next unless val.has_key?(:style)  # Skip if no style options
          val[:style].each_with_index do |s, s_idx| # Go through all of the configured ifs
            if s[:value]
              if e = MiqExpression.atom_error(rpt.col_to_expression_col(col.split("__").first), # See if the value is in error
                                              s[:operator],
                                              s[:value])
                order = case s_idx + 1 when 1;"first" when 2;"second" when 3;"third" end
                add_flash(I18n.t("flash.edit.field_styling_error.#{order}", :field=>f.first) + e.message, :error)
                @sb[:miq_tab] = "new_9"
              end
            end
          end
        end
      end
    end

    unless rpt.valid? # Check the model for errors
      rpt.errors.each do |field,msg|
        add_flash("#{field.to_s.capitalize} #{msg}", :error)
        @sb[:miq_tab] = "new_1"
      end
    end

    return @flash_array.nil?
  end

  # Check for tab switch error conditions
  def check_tabs
    @sb[:miq_tab] = params[:tab]
    case @sb[:miq_tab].split("_")[1]
    when "8"
      if @edit[:new][:fields].length == 0
        add_flash(I18n.t("flash.edit.tab_needs.1_field", :tab=>"Consolidation"), :error)
        @sb[:miq_tab] = "new_1"
      end
    when "2"
      if @edit[:new][:fields].length == 0
        add_flash(I18n.t("flash.edit.tab_needs.1_field", :tab=>"Formatting"), :error)
        @sb[:miq_tab] = "new_1"
      end
    when "3"
      if @edit[:new][:model] == TREND_MODEL
        unless @edit[:new][:perf_trend_col]
          add_flash(I18n.t("flash.edit.tab_needs.field_selected", :tab=>"Filter", :field=>"Trending for"), :error)
          @sb[:miq_tab] = "new_1"
        end
        unless @edit[:new][:perf_limit_col] ||@edit[:new][:perf_limit_val]
          add_flash(I18n.t("flash.edit.tab_needs.field_configured", :tab=>"Filter", :field=>"Trending Target Limit"), :error)
          @sb[:miq_tab] = "new_1"
        end
        if @edit[:new][:perf_limit_val] && !is_numeric?(@edit[:new][:perf_limit_val])
          add_flash(I18n.t("flash.edit.field_must_be.numeric", :field=>"Trend Target Limit"), :error)
          @sb[:miq_tab] = "new_1"
        end
      else
        if @edit[:new][:fields].length == 0
          add_flash(I18n.t("flash.edit.tab_needs.1_field", :tab=>"Filter"), :error)
          @sb[:miq_tab] = "new_1"
        end
      end
    when "4"
      if @edit[:new][:fields].length == 0
        add_flash(I18n.t("flash.edit.tab_needs.1_field", :tab=>"Summary"), :error)
        @sb[:miq_tab] = "new_1"
      end
    when "5"
      if @edit[:new][:fields].length == 0
        add_flash(I18n.t("flash.edit.tab_needs.1_field", :tab=>"Charts"), :error)
        @sb[:miq_tab] = "new_1"
      elsif @edit[:new][:sortby1].blank? || @edit[:new][:sortby1] == NOTHING_STRING
        add_flash(I18n.t("flash.edit.tab_needs.sort_field", :tab=>"Charts"), :error)
        @sb[:miq_tab] = "new_4"
      end
    when "6"
      if @edit[:new][:fields].length == 0
        add_flash(I18n.t("flash.edit.tab_needs.1_field", :tab=>"Timeline"), :error)
        @sb[:miq_tab] = "new_1"
      else
        found = false
        @edit[:new][:fields].each do |field|
          if MiqReport.get_col_type(field[1]) == :datetime
            found = true
            break
          end
        end
        unless found
          add_flash(I18n.t("flash.edit.tab_needs.time_field", :tab=>"Timeline"), :error)
          @sb[:miq_tab] = "new_1"
        end
      end
    when "7"
      if @edit[:new][:model] == TREND_MODEL
        unless @edit[:new][:perf_trend_col]
          add_flash(I18n.t("flash.edit.tab_needs.field_selected", :tab=>"Preview", :field=>"Trending for"), :error)
          @sb[:miq_tab] = "new_1"
        end
        unless @edit[:new][:perf_limit_col] ||@edit[:new][:perf_limit_val]
          add_flash(I18n.t("flash.edit.tab_needs.field_configured", :tab=>"Preview", :field=>"Trend Target Limit"), :error)
          @sb[:miq_tab] = "new_1"
        end
        if @edit[:new][:perf_limit_val] && !is_numeric?(@edit[:new][:perf_limit_val])
          add_flash(I18n.t("flash.edit.field_must_be.numeric", :field=>"Trend Target Limit: Value"), :error)
          @sb[:miq_tab] = "new_1"
        end
      else
        if @edit[:new][:fields].length == 0
          add_flash(I18n.t("flash.edit.tab_needs.1_field", :tab=>"Preview"), :error)
          @sb[:miq_tab] = "new_1"
        elsif @edit[:new][:model] == "Chargeback"
          unless @edit[:new][:cb_show_typ] &&
                  ((@edit[:new][:cb_show_typ] == "owner" && @edit[:new][:cb_owner_id]) ||
                    (@edit[:new][:cb_show_typ] == "tag" && @edit[:new][:cb_tag_cat] && @edit[:new][:cb_tag_value]))
            add_flash(I18n.t("flash.edit.tab_needs.field_configured", :tab=>"Preview", :field=>"Chargeback Filters"), :error)
            @sb[:miq_tab] = "new_3"
          end
        end
      end
    when "9"
      if @edit[:new][:fields].length == 0
        add_flash(I18n.t("flash.edit.tab_needs.1_field", :tab => "Styling"), :error)
        @sb[:miq_tab] = "new_1"
      end
    end
  end

  def menu_repname_update(old_name,new_name)
    all_roles = MiqGroup.all
    all_roles.each do |role|
      rec = MiqGroup.find_by_description(role.name)
      menu = rec.settings[:report_menus] if rec.settings
      if !menu.nil?
        menu.each_with_index do |lvl1,i|
          lvl1[1].each_with_index do |lvl2,j|
            lvl2[1].each_with_index do |rep,k|
              if rep == old_name
                menu[i][1][j][1][k] = new_name
              end
            end
          end
        end
        rec.settings[:report_menus] = menu
        rec.save
      end
    end
  end

  def friendly_model_name(model)
    # First part is a model name
    tables = model.split(".")
    retname = ""
    # The rest are table names
    if tables.length > 1
      tables[1..-1].each do |t|
        retname += "." if !retname.blank?
        retname += Dictionary.gettext(t, :type=>:table, :notfound=>:titleize)
      end
    end
    retname = retname.blank? ? " " : retname + " : "  # Use space for base fields, add : to others
    return retname
  end

  # Create a report object from the current edit fields
  def create_report_object
    rpt_rec = MiqReport.new                         # Create a new report record
    set_record_vars(rpt_rec)                        # Set the fields into the record
    return rpt_rec                                  # Create a report object from the record
  end

  #Build the main reports tree
  def build_reports_tree(type, name)
    x_tree_init(name, type, "MiqReport", :full_ids => true)
    tree_nodes = x_build_dynatree(x_tree(name))

    # Fill in root node details
    root           = tree_nodes.first
    root[:title]   = "All Reports"
    root[:tooltip] = "All Reports"
    root[:icon]    = "folder.png"
    @temp[name]    = tree_nodes.to_json          # JSON object for tree loading
    x_node_set(tree_nodes.first[:key], name) unless x_node(name)  # Set active node to root if not set
  end

  # Add the children of a node that is being expanded (autoloaded), called by generic tree_autoload method
  def tree_add_child_nodes(id)
    x_get_child_nodes_dynatree(x_active_tree, id)
  end
end
