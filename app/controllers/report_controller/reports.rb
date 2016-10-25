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
    if role_allows?(:feature => "miq_report_widget_editor")
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
    if !miq_task.results_ready?
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
    @events_data = []
    time = Time.zone.now
    @events_data.push(tl_event(format_timezone(time, "UTC", nil), "Now", "red"))
    @events_data.push(tl_event(format_timezone(time - 5.seconds, "UTC", nil), "5 Seconds Ago"))
    @events_data.push(tl_event(format_timezone(time - 1.minute, "UTC", nil), "1 Minute Ago"))
    @events_data.push(tl_event(format_timezone(time - 5.minutes, "UTC", nil), "5 Minutes Ago"))
    @events_data.push(tl_event(format_timezone(time - 1.hour, "UTC", nil), "1 Hour Ago"))
    @events_data.push(tl_event(format_timezone(time - 1.day, "UTC", nil), "Yesterday"))
    @events_data.push(tl_event(format_timezone(time - 1.week, "UTC", nil), "Last Week"))
    @events_data.push(tl_event(format_timezone(time - 1.month, "UTC", nil), "Last Month"))
    @events_data.push(tl_event(format_timezone(time - 3.months, "UTC", nil), "3 Months Ago"))
    @events_data.push(tl_event(format_timezone(time - 1.year, "UTC", nil), "Last Year"))
    [{:data => [@events_data]}].to_json
  end

  def preview_timeline
    render :xml => session[:edit][:tl_xml]
    session[:edit][:tl_xml] = nil
  end

  # generate preview chart when editing report
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
      @no_checkboxes = !role_allows?(:feature => "miq_report_saved_reports_admin", :any => true)

      if params[:ppsetting]                                             # User selected new per page value
        @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
        @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
      end

      @sortcol = session["#{x_active_tree}_sortcol".to_sym].nil? ? 0 : session["#{x_active_tree}_sortcol".to_sym].to_i
      @sortdir = session["#{x_active_tree}_sortdir".to_sym].nil? ? "DESC" : session["#{x_active_tree}_sortdir".to_sym]

      report_id = from_cid(nodeid.split('_')[0])
      @view, @pages = get_view(MiqReportResult, :named_scope => [:with_current_user_groups_and_report, report_id])
      @sb[:timezone_abbr] = @timezone_abbr if @timezone_abbr

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

  def tl_event(tl_time, tl_text, tl_color = nil)
    {"start"       => tl_time,
     "title"       => tl_text,
     "description" => tl_text,
     "icon"        => ActionController::Base.helpers.image_path("16/blue-circle.png"),
     "color"       => tl_color
    }
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
