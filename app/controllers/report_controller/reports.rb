module ReportController::Reports
  extend ActiveSupport::Concern

  include_concern 'Editor'

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
    if role_allows(:feature => "miq_report_widget_editor")
      # all widgets for this report
      get_all_widgets("report", from_cid(nodes[3].split('_').last))
    end
    add_flash(_("Report has been successfully queued to run"))
    replace_right_cell(:replace_trees => [:reports, :savedreports])
  end

  def miq_report_save
    rr               = MiqReportResult.find(@sb[:pages][:rr_id])
    rr.save_for_user(session[:userid])                # Save the current report results for this user
    @_params[:sortby] = "last_run_on"
    view, _page = get_view(MiqReportResult, :named_scope => [:with_current_user_groups_and_report, @sb[:miq_report_id]])
    savedreports = view.table.data
    r = savedreports.first
    @right_cell_div  = "report_list"
    @right_cell_text ||= _("%{model} \"%{name}\"") % {:name => r.name, :model => "Saved Report"}
    add_flash(_("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:model => "MiqReport"), :name => r.name})
    replace_right_cell(:replace_trees => [:reports, :savedreports])
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
      add_flash(_("Report preview generation returned: Status [%{status}] Message [%{message}]") % {:status => miq_task.status, :message => miq_task.message},
                :error)
    else
      rr = miq_task.miq_report_result
      @html = report_build_html_table(rr.report, rr.html_rows(:page => 1, :per_page => 100).join)

      if rpt.timeline                   # If timeline present
        @timeline                 = true
        rpt.extras[:browser_name] = browser_info(:name)
        # flag to force formatter to build timeline in xml for preview screen
        rpt.extras[:tl_preview] = true
        @edit[:tl_xml]            = rpt.to_timeline
        @edit[:tl_position]       = format_timezone(rpt.extras[:tl_position], Time.zone, "tl")
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
    render :update do |page|
      page << javascript_prologue
      page.replace_html("form_preview", :partial => "form_preview")
      page << "miqSparkle(false);"
    end
  end

  def miq_report_delete
    assert_privileges("miq_report_delete")
    rpt = MiqReport.find(params[:id])

    if rpt.miq_widgets.exists?
      add_flash(_("Report cannot be deleted if it's being used by one or more Widgets"), :error)
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div_report_list", :partial => "layouts/flash_msg", :locals => {:div_num => "_report_list"})
      end
    else
      begin
        raise StandardError, "Default %{model} \"%{name}\" cannot be deleted" % {:model => ui_lookup(:model => "MiqReport"), :name => rpt.name} if rpt.rpt_type == "Default"
        rpt_name = rpt.name
        audit = {:event => "report_record_delete", :message => "[#{rpt_name}] Record deleted", :target_id => rpt.id, :target_class => "MiqReport", :userid => session[:userid]}
        rpt.destroy
      rescue StandardError => bang
        add_flash(_("%{model} \"%{name}\": Error during 'miq_report_delete': %{message}") %
                    {:model => ui_lookup(:model => "MiqReport"), :name => rpt_name, :message =>  bang.message}, :error)
        render :update do |page|
          page << javascript_prologue
          page.replace("flash_msg_div_report_list", :partial => "layouts/flash_msg", :locals => {:div_num => "_report_list"})
        end
        return
      else
        AuditEvent.success(audit)
        add_flash(_("%{model} \"%{name}\": Delete successful") % {:model => ui_lookup(:model => "MiqReport"), :name => rpt_name})
      end
      params[:id] = nil
      nodes = x_node.split('_')
      self.x_node = "#{nodes[0]}_#{nodes[1]}"
      replace_right_cell(:replace_trees => [:reports])
    end
  end

  def download_report
    assert_privileges("miq_report_export")
    @yaml_string = MiqReport.export_to_yaml(params[:id] ? [params[:id]] : @sb[:choices_chosen], MiqReport)
    file_name    = "Reports_#{format_timezone(Time.now, Time.zone, "export_filename")}.yaml"
    disable_client_cache
    send_data(@yaml_string, :filename => file_name)
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
    render :xml => tl_xml.to_s
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

  # get saved reports for a specific report
  def get_all_reps(nodeid = nil)
    # set nodeid from @sb, incase sort was pressed
    nodeid = x_active_tree == :reports_tree ?
        x_node.split('-').last :
        x_node.split('-').last.split('_')[0] if nodeid.nil?
    @sb[:miq_report_id] = from_cid(nodeid)
    @record = @miq_report = MiqReport.find(@sb[:miq_report_id])
    if @sb[:active_tab] == "saved_reports" || x_active_tree == :savedreports_tree
      @force_no_grid_xml   = true
      @gtl_type            = "list"
      @ajax_paging_buttons = true
      @no_checkboxes = !role_allows(:feature => "miq_report_saved_reports_admin", :any => true)

      if params[:ppsetting]                                             # User selected new per page value
        @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
        @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
      end

      @sortcol = session["#{x_active_tree}_sortcol".to_sym].nil? ? 0 : session["#{x_active_tree}_sortcol".to_sym].to_i
      @sortdir = session["#{x_active_tree}_sortdir".to_sym].nil? ? "DESC" : session["#{x_active_tree}_sortdir".to_sym]

      report_id = from_cid(nodeid.split('_')[0])
      @view, @pages = get_view(MiqReportResult, :named_scope => [:with_current_user_groups_and_report, report_id])
      @sb[:timezone_abbr] = @timezone_abbr if @timezone_abbr
      # Saving converted time to be displayed on saved reports list view
      @view.table.data.each_with_index do |s, _s_idx|
        @report_running = true if s.status.downcase == "running" || s.status.downcase == "queued"
      end

      @current_page = @pages[:current] unless @pages.nil? # save the current page number
      session["#{x_active_tree}_sortcol".to_sym] = @sortcol
      session["#{x_active_tree}_sortdir".to_sym] = @sortdir
    end

    if @sb[:active_tab] == "report_info"
      schedules = MiqSchedule.where(:towhat => "MiqReport")
      schedules = schedules.where(:userid => current_userid) unless super_admin_user?
      @schedules = schedules.select { |s| s.filter.exp["="]["value"].to_i == @miq_report.id.to_i }.sort_by(&:name)

      @widget_nodes = @miq_report.miq_widgets.to_a
    end

    @sb[:tree_typ]   = "reports"
    @right_cell_text = _("%{model} \"%{name}\"") % {:name => @miq_report.name, :model => ui_lookup(:model => "MiqReport")}
  end

  def rep_change_tab
    @sb[:active_tab] = params[:tab_id]
    replace_right_cell
  end

  private

  def tl_event(tl, tl_time, tl_text, tl_color = nil)
    event = tl.root.add_element("event",
                                "start" => tl_time,
                                #                                       "end" => Time.now,
                                #                                       "isDuration" => "true",
                                "title" => tl_text,
                                #         "icon"=>"/images/16/16-event-vm_snapshot.png",
                                "icon"  => ActionController::Base.helpers.image_path("16/blue-circle.png"),
                                #         "image"=>"/images/64/64-snapshot.png",
                                "color" => tl_color
                               # "image"=>"/images/64/64-vendor-#{vm.vendor.downcase}.png"
                               )
    event.text = tl_text
  end

  # Check for valid report configuration in @edit[:new]
  def valid_report?(rpt)
    active_tab = "edit_1"
    if @edit[:new][:model] == TREND_MODEL
      unless @edit[:new][:perf_trend_col]
        add_flash(_("Trending for is required"), :error)
      end
      unless @edit[:new][:perf_limit_col] || @edit[:new][:perf_limit_val]
        add_flash(_("Trend Target Limit must be configured"), :error)
      end
      if @edit[:new][:perf_limit_val] && !is_numeric?(@edit[:new][:perf_limit_val])
        add_flash(_("Trend Target Limit must be numeric"), :error)
      end
    else
      if @edit[:new][:fields].length == 0
        add_flash(_("At least one Field must be selected"), :error)
      end
    end

    if @edit[:new][:model].to_s.starts_with?("Chargeback")
      unless @edit[:new][:cb_show_typ]
        add_flash(_("Show Costs by must be selected"), :error)
        active_tab = "edit_3"
      else
        if @edit[:new][:cb_show_typ] == "owner"
          unless @edit[:new][:cb_owner_id]
            add_flash(_("An Owner must be selected"), :error)
            active_tab = "edit_3"
          end
        elsif @edit[:new][:cb_show_typ] == "tenant" && !@edit[:new][:cb_tenant_id]
          add_flash(_("A Tenant Category must be selected"), :error)
          active_tab = "edit_3"
        elsif @edit[:new][:cb_show_typ] == "tag"
          unless @edit[:new][:cb_tag_cat]
            add_flash(_("A Tag Category must be selected"), :error)
            active_tab = "edit_3"
          else
            unless @edit[:new][:cb_tag_value]
              add_flash(_("A Tag must be selected"), :error)
              active_tab = "edit_3"
            end
          end
        elsif @edit[:new][:cb_show_typ] == "entity"
          unless @edit[:new][:cb_entity_id]
            add_flash(_("A specific #{ui_lookup(:model => @edit[:new][:cb_model])} or all must be selected"), :error)
            active_tab = "edit_3"
          end
        end
      end
    end

    # Validate column styles
    unless rpt.col_options.blank? || @edit[:new][:field_order].nil?
      @edit[:new][:field_order].each do |f| # Go thru all of the cols in order
        col = f.last.split(".").last.split("-").last
        if val = rpt.col_options[col] # Skip if no options for this col
          next unless val.key?(:style)  # Skip if no style options
          val[:style].each_with_index do |s, s_idx| # Go through all of the configured ifs
            if s[:value]
              if e = MiqExpression.atom_error(rpt.col_to_expression_col(col.split("__").first), # See if the value is in error
                                              s[:operator],
                                              s[:value])
                msg = case s_idx + 1
                      when 1
                        add_flash(_("Styling for '%{item}', first value is in error: %{message}") %
                                    {:item => f.first, :message => e.message}, :error)
                      when 2
                        add_flash(_("Styling for '%{item}', second value is in error: %{message}") %
                                    {:item => f.first, :message => e.message}, :error)
                      when 3
                        add_flash(_("Styling for '%{item}', third value is in error: %{message}") %
                                    {:item => f.first, :message => e.message}, :error)
                      end
                active_tab = "edit_9"
              end
            end
          end
        end
      end
    end

    unless rpt.valid? # Check the model for errors
      rpt.errors.each do |field, msg|
        add_flash("#{field.to_s.capitalize} #{msg}", :error)
      end
    end
    @sb[:miq_tab] = active_tab if flash_errors?
    @flash_array.nil?
  end

  # Check if chargeback field is valid
  def valid_chargeback_fields
    is_valid = false
    # There are valid show typ fields
    if %w(owner tenant tag entity).include?(@edit[:new][:cb_show_typ])
      is_valid = case @edit[:new][:cb_show_typ]
                 when "owner" then @edit[:new][:cb_owner_id]
                 when "tenant" then @edit[:new][:cb_tenant_id]
                 when "tag" then @edit[:new][:cb_tag_cat] && @edit[:new][:cb_tag_value]
                 when "entity" then @edit[:new][:cb_entity_id] && @edit[:new][:cb_provider_id]
                 end
    end
    is_valid
  end
  # Check for tab switch error conditions
  def check_tabs
    @sb[:miq_tab] = params[:tab]
    active_tab = "edit_1"
    case @sb[:miq_tab].split("_")[1]
    when "8"
      if @edit[:new][:fields].length == 0
        add_flash(_("Consolidation tab is not available until at least 1 field has been selected"), :error)
      end
    when "2"
      if @edit[:new][:fields].length == 0
        add_flash(_("Formatting tab is not available until at least 1 field has been selected"), :error)
      end
    when "3"
      if @edit[:new][:model] == TREND_MODEL
        unless @edit[:new][:perf_trend_col]
          add_flash(_("Filter tab is not available until Trending for field has been selected"), :error)
        end
        unless @edit[:new][:perf_limit_col] || @edit[:new][:perf_limit_val]
          add_flash(_("Filter tab is not available until Trending Target Limit has been configured"), :error)
        end
        if @edit[:new][:perf_limit_val] && !is_numeric?(@edit[:new][:perf_limit_val])
          add_flash(_("%s must be numeric") % "Trend Target Limit", :error)
        end
      else
        if @edit[:new][:fields].length == 0
          add_flash(_("Filter tab is not available until at least 1 field has been selected"), :error)
        end
      end
    when "4"
      if @edit[:new][:fields].length == 0
        add_flash(_("Summary tab is not available until at least 1 field has been selected"), :error)
      end
    when "5"
      if @edit[:new][:fields].length == 0
        add_flash(_("Charts tab is not available until at least 1 field has been selected"), :error)
      elsif @edit[:new][:sortby1].blank? || @edit[:new][:sortby1] == NOTHING_STRING
        add_flash(_("Charts tab is not available unless a sort field has been selected"), :error)
        active_tab = "edit_4"
      end
    when "6"
      if @edit[:new][:fields].length == 0
        add_flash(_("Timeline tab is not available until at least 1 field has been selected"), :error)
      else
        found = false
        @edit[:new][:fields].each do |field|
          if MiqReport.get_col_type(field[1]) == :datetime
            found = true
            break
          end
        end
        unless found
          add_flash(_("Timeline tab is not available unless at least 1 time field has been selected"), :error)
        end
      end
    when "7"
      if @edit[:new][:model] == TREND_MODEL
        unless @edit[:new][:perf_trend_col]
          add_flash(_("Preview tab is not available until Trending for field has been selected"), :error)
        end
        unless @edit[:new][:perf_limit_col] || @edit[:new][:perf_limit_val]
          add_flash(_("Preview tab is not available until Trend Target Limit has been configured"), :error)
        end
        if @edit[:new][:perf_limit_val] && !is_numeric?(@edit[:new][:perf_limit_val])
          add_flash(_("Trend Target Limit: Value must be numeric"), :error)
        end
      else
        if @edit[:new][:fields].length == 0
          add_flash(_("Preview tab is not available until at least 1 field has been selected"), :error)
        elsif Chargeback.db_is_chargeback?(@edit[:new][:model]) && !valid_chargeback_fields
          add_flash(_("Preview tab is not available until Chargeback Filters has been configured"), :error)
          active_tab = "edit_3"
        end
      end
    when "9"
      if @edit[:new][:fields].length == 0
        add_flash(_("Styling tab is not available until at least 1 field has been selected"), :error)
      end
    end
    @sb[:miq_tab] = active_tab if flash_errors?
  end

  def menu_repname_update(old_name, new_name)
    all_roles = MiqGroup.non_tenant_groups_in_my_region
    all_roles.each do |role|
      rec = MiqGroup.find_by_description(role.name)
      menu = rec.settings[:report_menus] if rec.settings
      unless menu.nil?
        menu.each_with_index do |lvl1, i|
          lvl1[1].each_with_index do |lvl2, j|
            lvl2[1].each_with_index do |rep, k|
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
        retname += "." unless retname.blank?
        retname += Dictionary.gettext(t, :type => :table, :notfound => :titleize)
      end
    end
    retname = retname.blank? ? " " : retname + " : "  # Use space for base fields, add : to others
    retname
  end

  # Create a report object from the current edit fields
  def create_report_object
    rpt_rec = MiqReport.new                         # Create a new report record
    set_record_vars(rpt_rec)                        # Set the fields into the record
    rpt_rec                                  # Create a report object from the record
  end

  # Build the main reports tree
  def build_reports_tree
    reports_menu_in_sb
    TreeBuilderReportReports.new('reports_tree', 'reports', @sb)
  end
end
