module ApplicationController::Timelines
  extend ActiveSupport::Concern

  # Process changes to timeline selection
  def tl_chooser
    @record = identify_tl_or_perf_record
    @tl_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record
    tl_build_timeline
    @tl_options.date.update_from_params(params)

    if @tl_options.management_events?
      @tl_options.management.update_from_params(params)
    else
      @tl_options.policy.update_from_params(params)
    end

    if (@tl_options.management_events? && !@tl_options.management.categories.blank?) ||
       (@tl_options.policy_events? && !@tl_options.policy.categories.blank?)
      tl_gen_timeline_data(refresh = "n")
      return unless @timeline
    end

    @timeline = true
    add_flash(_("No events available for this timeline"), :warning) if @tl_options.date.start.nil? && @tl_options.date.end.nil?
    render :update do |page|
      page << javascript_prologue
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      page.replace("tl_div", :partial => "layouts/tl_detail")
      page << "ManageIQ.calendar.calDateFrom = new Date(#{@tl_options.date.start});" unless @tl_options.date.start.nil?
      page << "ManageIQ.calendar.calDateTo = new Date(#{@tl_options.date.end});" unless @tl_options.date.end.nil?
      page << 'miqBuildCalendar();'
      page << "miqSparkle(false);"
    end
  end

  def timeline_data
    blob = BinaryBlob.find(session[:tl_xml_blob_id])
    render :xml => blob.binary
    blob.destroy
  end

  private ############################

  # Gather information for the report/timeline menu trees accordians
  def build_timeline_tree(rpt_menu, tree_type)
    @rep_tree = {}
    @group_idx = []
    @report_groups = []
    @branch = []
    @tree_type = tree_type
    rpt_menu.each do |r|
      @group_idx.push(r[0]) unless @group_idx.include?(r[0])
      @report_groups.push(r[0]) unless @report_groups.include?(r[0])
      r.each_slice(2) do |menu, section|
        section.each_with_index do |s, j|
          if s.class == Array
            s.each do |rec|
              @branch_node = []
              if rec.class == String
                @parent_node = {}
                @parent_node = TreeNodeBuilder.generic_tree_node(
                  "p__#{rec}",
                  rec,
                  "folder.png",
                  _("Group: %{name}") % {:name => rec},
                  :cfme_no_click => true
                )
              else
                rec.each_with_index do |r, i|
                  if i.even?
                    nodecolor = "#dddddd"
                  else
                    nodecolor = ""
                  end
                  temp = timeline_kids_tree(r, nodecolor)
                  @branch_node.push(temp) unless temp.nil? || temp.empty?
                end
                @parent_node[:children] = @branch_node unless @branch_node.nil? || @parent_node.include?(@branch_node)
              end
              @branch.push(@parent_node) unless @parent_node.nil? || @branch.include?(@parent_node)
            end
          elsif s.class == String
            if j.even?
              nodecolor = "#dddddd"
            else
              nodecolor = ""
            end
            temp = timeline_kids_tree(s, nodecolor)
            @branch.push(temp) unless temp.nil? || temp.empty?
          end
        end
        @rep_tree[menu] = TreeBuilder.convert_bs_tree(@branch).to_json unless @branch.nil? || @branch.empty?
        @branch = []
      end
    end
  end

  def timeline_kids_tree(rec, node_color)
    rpt = MiqReport.find_by_name(rec)
    @tag_node = {}
    unless rpt.nil?
      @tag_node = TreeNodeBuilder.generic_tree_node(
        "#{rpt.id}__#{rpt.name}",
        rpt.name,
        "link_internal.gif",
        _("Report: %{name}") % {:name => rpt.name}
      )
    end
    @tag_node
  end

  def tl_get_rpt(timeline)
    MiqReport.new(YAML.load(File.open("#{TIMELINES_FOLDER}/miq_reports/#{timeline}.yaml")))
  end

  def tl_build_init_options(refresh = nil)
    @tl_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record
    if @tl_options.nil? ||
       (refresh != "n" && params[:refresh] != "n" && @tl_options[:model] != @tl_record.class.base_class.to_s)
      @tl_options = Options.new
      @tl_options.date.typ = 'Daily'
      @tl_options.date.days = '7'
      @tl_options[:model] = @tl_record.class.base_class.to_s
      @tl_options.policy.categories = []
    end
    @tl_options.tl_show = params[:tl_show] || "timeline"
    sdate, edate = @tl_record.first_and_last_event(@tl_options.evt_type)
    @tl_options.date.update_start_end(sdate, edate)

    if @tl_options.policy_events?
      @tl_options.policy.result ||= "both"

      @tl_options.policy.categories ||= []
      if @tl_options.policy.categories.blank?
        @tl_options.policy.categories.push("VM Operation")
        # had to set this here because if it this is preselected in cboxes, it doesnt send the params back for this cb to tl_chooser
        @tl_options.policy.events.keys.sort.each_with_index do |e, i|
          if e == "VM Operation"
            @tl_options.policy.categories[i] = e
          end
        end
      end
    elsif @tl_options.management.level.nil?
      @tl_options.management.level = "critical"
    end
  end

  def tl_build_timeline_report_options
    if !@tl_options.date.start.nil? && !@tl_options.date.end.nil?
      case @tl_options.date.typ
      when "Hourly"
        tl_rpt = @tl_options.management_events? ? "tl_events_hourly" : "tl_policy_events_hourly"
        @report = tl_get_rpt(tl_rpt)
        @report.headers.map! { |header| _(header) }
        mm, dd, yy = @tl_options.date.hourly.split("/")
        from_dt = create_time_in_utc("#{yy}-#{mm}-#{dd} 00:00:00", session[:user_tz]) # Get tz 12am in user's time zone
        to_dt = create_time_in_utc("#{yy}-#{mm}-#{dd} 23:59:59", session[:user_tz])   # Get tz 11pm in user's time zone
        st_time = Time.gm(yy, mm, dd, 00, 00, 00)
        end_time = Time.gm(yy, mm, dd, 23, 59, 00)
        #        START of TIMELINE TIMEZONE Code
        #        @report.timeline[:bands][0][:center_position] = Time.gm(yy,mm,dd,21,00,00)    # calculating mid position to align timeline in center
        #        @report.timeline[:bands][0][:st_time] = st_time.strftime("%b %d %Y 00:00:00 GMT")
        #        @report.timeline[:bands][0][:end_time] = end_time.strftime("%b %d %Y 23:59:00 GMT")
        tz = @report.tz ? @report.tz : Time.zone
      when "Daily"
        tl_rpt = @tl_options.management_events? ? "tl_events_daily" : "tl_policy_events_daily"
        @report = tl_get_rpt(tl_rpt)
        @report.headers.map! { |header| _(header) }
        from = Date.parse(@tl_options.date.daily) - @tl_options.date.days.to_i
        from_dt = create_time_in_utc("#{from.year}-#{from.month}-#{from.day} 00:00:00", session[:user_tz])  # Get tz 12am in user's time zone
        mm, dd, yy = @tl_options.date.daily.split("/")
        to_dt = create_time_in_utc("#{yy}-#{mm}-#{dd} 23:59:59", session[:user_tz]) # Get tz 11pm in user's time zone
      end

      temp_clause = @tl_record.event_where_clause(@tl_options.evt_type)

      cond = "( "
      cond = cond << temp_clause[0]
      params = temp_clause.slice(1, temp_clause.length)

      event_set = @tl_options.event_set
      if !event_set.empty?
        if @tl_options.policy_events? && @tl_options.policy.result != "both"
          where_clause = [") and (timestamp >= ? and timestamp <= ?) and (event_type in (?)) and (result = ?)",
                          from_dt,
                          to_dt,
                          event_set.flatten,
                          @tl_options.policy.result]
        else
          where_clause = [") and (timestamp >= ? and timestamp <= ?) and (event_type in (?))",
                          from_dt,
                          to_dt,
                          event_set.flatten]
        end
      else
        where_clause = [") and (timestamp >= ? and timestamp <= ?)",
                        from_dt,
                        to_dt]
      end
      cond << where_clause[0]

      params2 = where_clause.slice(1, where_clause.length - 1)
      params = params.concat(params2)
      @report.where_clause = [cond, *params]
      @report.rpt_options ||= {}
      @report.rpt_options[:categories] =
        @tl_options.management_events? ? @tl_options.management.categories : @tl_options.policy.categories
      @title = @report.title
    end
  end

  def tl_build_timeline(refresh = nil)
    tl_build_init_options(refresh)                # Intialize options(refresh) if !@report
    @ajax_action = "tl_chooser"
  end

  def tl_gen_timeline_data(refresh = nil)
    tl_build_timeline(refresh)
    tl_build_timeline_report_options
    @timeline = true unless @report         # need to set this incase @report is not there, when switching between Management/Policy events
    if @report
      unless params[:task_id]                                     # First time thru, kick off the report generate task
        initiate_wait_for_task(:task_id => @report.async_generate_table(:userid => session[:userid]))
        return
      end

      @timeline = true
      miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
      @report = miq_task.task_results

      if !miq_task.results_ready?
        add_flash(_("Error building timeline %{error_message}") % {:error_message => miq_task.message}, :error)
      else
        @timeline = @timeline_filter = true
        if @report.table.data.length == 0
          add_flash(_("No records found for this timeline"), :warning)
        else
          @report.extras[:browser_name] = browser_info(:name)
          @tl_json = @report.to_timeline
          #         START of TIMELINE TIMEZONE Code
          session[:tl_position] = @report.extras[:tl_position]
          #         session[:tl_position] = format_timezone(@report.extras[:tl_position],Time.zone,"tl")
          #         END of TIMELINE TIMEZONE Code
        end
      end
    end
  end

  def set_tl_session_data(options = @tl_options, controller = controller_name)
    unless options.nil?
      options.drop_cache
      session["#{controller}_tl".to_sym] = options unless options.nil?
    end
  end

  def tl_session_data(controller = controller_name)
    session["#{controller}_tl".to_sym]
  end
end
