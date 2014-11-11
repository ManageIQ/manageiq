module ReportController::SavedReports
  extend ActiveSupport::Concern

  def show_saved
    @sb[:last_saved_id] = params[:id] if params[:id] && params[:id] != "report"
    fetch_saved_report(@sb[:last_saved_id])
    if @report.blank? # if report was nil. reset active tree back to report tree, and keep active node report to be same
      self.x_active_tree = :reports_tree
    else              # else update active node
      # if coming from email link, active_node doesnt exist or after saving a report and changing accordion saved node doesnt exist
      #x_node_set(x_node(:savedreports_tree), :reports_tree) if x_tree(:savedreports_tree) && x_node(:savedreports_tree)
    end
  end

  def show_saved_report
    @sb[:last_savedreports_id] = params[:id].split('-').last if params[:id] && params[:id] != "savedreports"
    fetch_saved_report(@sb[:last_savedreports_id])
  end

  def fetch_saved_report(id)
    rr = MiqReportResult.find_by_id(from_cid(id.split('-').last))
    if rr.nil?  # Saved report no longer exists
      @report = nil
      return
    end
    @right_cell_text ||= _("%{model} \"%{name}\"") % {:name=>"#{rr.name} - #{format_timezone(rr.created_on,Time.zone,"gt")}", :model=>"Saved Report"}
    user = User.find_by_userid(session[:userid])
    if user.admin_user? || rr.miq_group_id == session[:group]
      @report_result_id = session[:report_result_id] = rr.id
      session[:report_result_runtime] = rr.last_run_on
      task = MiqTask.find_by_id(rr.miq_task_id)
      if rr.status.downcase == "finished"
        @report = rr.report_results
        session[:rpt_task_id] = nil
        if @report.blank?
          add_flash(_("Saved Report \"%s\" not found, Schedule may have failed") % format_timezone(rr.created_on,Time.zone,"gtl"),
                    :error)
          get_all_reps(rr.miq_report_id.to_s)
          if x_active_tree == :savedreports_tree
            self.x_node = "xx-#{to_cid(rr.miq_report_id)}"
          else
            @sb[:rpt_menu].each_with_index do |lvl1,i|
              if lvl1[0] == @sb[:grp_title]
                lvl1[1].each_with_index do |lvl2,k|
                  if lvl2[0].downcase == "custom"
                    x_node_set("xx-#{i}_xx-#{i}-#{k}_rep-#{to_cid(rr.miq_report_id)}", :reports_tree)
                  end
                end
              end
            end
          end
          return
        else
          if @report.contains_records?
            @html = report_first_page(rr)             # Get the first page of the results
            if params[:type]
              @zgraph = nil
              @html   = nil
              if ["tabular", "hybrid"].include?(params[:type])
                @html = report_build_html_table(@report,
                                                rr.html_rows(:page=>@sb[:pages][:current],
                                                             :per_page=>@sb[:pages][:perpage]).join)
              end
              if ["graph", "hybrid"].include?(params[:type])
                @zgraph = true      # Show the zgraph in the report
              end
              @ght_type = params[:type]
            else
              unless @report.graph.blank?
                @zgraph   = true
                @ght_type = "hybrid"
              else
                @ght_type = "tabular"
              end
            end
            @report.extras           ||= Hash.new     # Create extras hash
            @report.extras[:to_html] ||= @html        # Save the html report
          else
            add_flash(_("No records found for this report"), :warning)
          end
        end
      else      #report is queued/running/error
        @temp[:report_result] = rr
      end
    else
      add_flash(_("Report is not authorized for the logged in user"), :error)
      get_all_reps(@sb[:miq_report_id].to_s)
      return
    end
  end

  # Delete all selected or single displayed host(s)
  def saved_report_delete
    assert_privileges("saved_report_delete")
    savedreports = find_checked_items
    if savedreports.empty? && params[:id].present? && !MiqReportResult.exists?(params[:id].to_i)
      # saved report is being viewed in report accordion
      add_flash(_("%s no longer exists") % "Saved Report", :error)
    else
      savedreports.push(params[:id]) if savedreports.blank?
      @report = nil
      r = MiqReportResult.find(savedreports[0])
      @sb[:miq_report_id] = r.miq_report_id
      process_saved_reports(savedreports, "destroy")  if ! savedreports.empty?
      add_flash(_("The selected %s was deleted") % "Saved Report") if @flash_array.nil?
    end
    self.x_node = "xx-#{to_cid(@sb[:miq_report_id])}" if x_active_tree == :savedreports_tree &&
        x_node.split('-').first == "rr"
    @sb[:rep_tree_build_time] = Time.now.utc
    replace_right_cell(:replace_trees => [:reports,:savedreports])
  end

  #get all saved reports for list view
  def get_all_saved_reports
    @force_no_grid_xml   = true
    @gtl_type            = "list"
    @ajax_paging_buttons = true
#   @embedded = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end

    @sortcol = session["#{x_active_tree}_sortcol".to_sym].nil? ? 0 : session["#{x_active_tree}_sortcol".to_sym].to_i
    @sortdir = session["#{x_active_tree}_sortdir".to_sym].nil? ? "DESC" : session["#{x_active_tree}_sortdir".to_sym]
    #show all saved reports
    @view, @pages = get_view(MiqReportResult, :association=>"all", :where_clause=>set_saved_reports_condition)

    #build_savedreports_tree
    @sb[:saved_reports] = nil
    @right_cell_div     = "savedreports_list"
    @right_cell_text    = _("All %s") % "Saved Reports"

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    session["#{x_active_tree}_sortcol".to_sym] = @sortcol
    session["#{x_active_tree}_sortdir".to_sym] = @sortdir
  end

  private

  #Build the main Saved Reports tree
  def build_savedreports_tree(type=:savedreports, name=:savedreports_tree)
    x_tree_init(name, type, 'All Saved Reports')
    tree_nodes = x_build_dynatree(x_tree(name))

    # Fill in root node details
    root           = tree_nodes.first
    root[:title]   = "All Saved Reports"
    root[:tooltip] = "All Saved Reports"
    root[:icon]    = "folder.png"
    @temp[name]    = tree_nodes.to_json          # JSON object for tree loading
    x_node_set(tree_nodes.first[:key], name) unless x_node(name)  # Set active node to root if not set
  end

  # Add the children of a node that is being expanded (autoloaded), called by generic tree_autoload method
  def tree_add_child_nodes(id)
    x_get_child_nodes_dynatree(x_active_tree, id)
  end

  def set_saved_reports_condition(rep_id=nil)
    u = User.find_by_userid(session[:userid])
    cond = Array.new

    # Replaced this code as all saved, requested, scheduled reports have miq_report_id set, others don't
    #cond[0] = "(report_source=? OR report_source=? OR report_source=?)"
    #cond.push("Saved by user")
    #cond.push("Requested by user")
    #cond.push("Scheduled")

    if rep_id.nil?
      cond[0] = "miq_report_id IS NOT NULL"
    else
      cond[0] = "miq_report_id=?"
      cond.push(rep_id)
    end

    # Admin users can see all saved reports
    unless u.admin_user?
      cond[0] << " AND miq_group_id=?"
      cond.push(session[:group])
    end

    return cond.flatten
  end

end
