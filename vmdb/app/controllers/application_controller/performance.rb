module ApplicationController::Performance
  extend ActiveSupport::Concern

  # Process changes to performance charts
  def perf_chart_chooser
    assert_privileges("perf_reload")
    @record = identify_tl_or_perf_record
    @perf_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record

    unless params[:task_id] # First time thru, gather options changed by the user
      @perf_options[:typ]        = params[:perf_typ]          if params[:perf_typ]
      @perf_options[:days]       = params[:perf_days]         if params[:perf_days]
      @perf_options[:rt_minutes] = params[:perf_minutes].to_i if params[:perf_minutes]
      @perf_options[:hourly_date] = params[:miq_date_1] if params[:miq_date_1] && @perf_options[:typ] == "Hourly"
      @perf_options[:daily_date]  = params[:miq_date_1] if params[:miq_date_1] && @perf_options[:typ] == "Daily"
      @perf_options[:index]       = params[:chart_idx] == "clear" ? nil : params[:chart_idx] if params[:chart_idx]
      @perf_options[:parent]      = params[:compare_to].blank? ? nil : params[:compare_to] if params.has_key?(:compare_to)
      @perf_options[:compare_vm]  = params[:compare_vm].blank? ? nil : params[:compare_vm] if params.has_key?(:compare_vm)
      if params[:perf_cat]
        if params[:perf_cat] == "<None>"
          @perf_options[:cat_model] = nil
          @perf_options[:cat] = nil
        else
          @perf_options[:cat_model], @perf_options[:cat] = params[:perf_cat].split(":")
        end
      end
      if params[:perf_vmtype]
        @perf_options[:vmtype] = params[:perf_vmtype] == "<All>" ? nil : params[:perf_vmtype]
      end
      if params.has_key?(:time_profile)
        tp = TimeProfile.find(params[:time_profile]) unless params[:time_profile].blank?
        @perf_options[:time_profile] = params[:time_profile].blank? ? nil : params[:time_profile].to_i
        @perf_options[:tz] = @perf_options[:time_profile_tz] = params[:time_profile].blank? ? nil : tp.tz
        @perf_options[:time_profile_days] = params[:time_profile].blank? ? nil : tp.days
      end
    end

    case @perf_options[:chart_type]
    when :performance
      perf_set_or_fix_dates(@perf_options)  unless params[:task_id] # Set dates if first time thru
      unless @temp[:no_util_data]
        perf_gen_data(refresh="n")      # Go generate the task
        return unless @temp[:charts]    # Return if no charts got created (first time thru async rpt gen)
      end
    end

    render :update do |page|
      if @temp[:parent_chart_data]
        page << 'miq_chart_data = ' + {"candu" => @temp[:chart_data], "parent"    => @temp[:parent_chart_data]}.to_json + ';'
      elsif @temp[:compare_vm_chart_data]
        page << 'miq_chart_data = ' + {"candu" => @temp[:chart_data], "comparevm" => @temp[:compare_vm_chart_data]}.to_json + ';'
      else
        page << 'miq_chart_data = ' + {"candu" => @temp[:chart_data]}.to_json + ';'
      end

# Cannot replace button divs that contain dhtmlx toolbars, use code below to turn on/off individual buttons
#     page.replace("view_buttons_div", :partial=>"layouts/view_buttons")  # Don't need to do view or center buttons, just the perf stuff
#     page.replace("center_buttons_div", :partial=>"layouts/center_buttons")
      if ["host","vm","vm_or_template"].include?(params[:controller])
        pfx = params[:controller] == "vm_or_template" ? "vm_" : ""
        if @perf_options[:typ] == "realtime"
          page << "if(center_tb) center_tb.showItem('#{pfx}perf_refresh');"
          page << "if(center_tb) center_tb.showItem('#{pfx}perf_reload');"
          page << "if(center_tb) center_tb.enableItem('#{pfx}perf_refresh');"
          page << "if(center_tb) center_tb.enableItem('#{pfx}perf_reload');"
        else
          page << "if(center_tb) center_tb.hideItem('#{pfx}perf_refresh');"
          page << "if(center_tb) center_tb.hideItem('#{pfx}perf_reload');"
        end
      end

      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      page.replace("perf_options_div", :partial=>"layouts/perf_options")
      page.replace("candu_charts_div", :partial=>"layouts/perf_charts",
                  :locals => {:chart_data => @temp[:chart_data], :chart_set => "candu"})
      unless @temp[:no_util_data]
        if @perf_options[:typ] == "Hourly"
          page << "miq_cal_dateFrom = new Date(#{@perf_options[:sdate].year},#{@perf_options[:sdate].month-1},#{@perf_options[:sdate].day});"
          page << "miq_cal_dateTo   = new Date(#{@perf_options[:edate].year},#{@perf_options[:edate].month-1},#{@perf_options[:edate].day});"
        else
          page << "miq_cal_dateFrom = new Date(#{@perf_options[:sdate_daily].year},#{@perf_options[:sdate_daily].month-1},#{@perf_options[:sdate_daily].day});"
          page << "miq_cal_dateTo   = new Date(#{@perf_options[:edate_daily].year},#{@perf_options[:edate_daily].month-1},#{@perf_options[:edate_daily].day});"
        end
      end
      if @perf_options[:skip_days]
        page << "miq_cal_skipDays = '#{@perf_options[:skip_days]}';"
      else
        page << "miq_cal_skipDays = null;"
      end
      page << 'miqBuildCalendar();'
      page << Charting.js_load_statement
      page << 'miqSparkle(false);'
      if request.parameters["controller"] == "storage" && @perf_options[:cat]
        page << "$('perf_typ').disable();"
      end
    end
  end

  # Generate a chart with the top CIs for a given timestamp
  def perf_top_chart
    return if perfmenu_click?

    @record = identify_tl_or_perf_record
    @perf_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record
    if params[:menu_choice]
      legend_idx = params[:menu_choice].split("_").last.split("-").first.to_i - 1
      data_idx = params[:menu_choice].split("_").last.split("-")[-2].to_i - 1
      chart_idx = params[:menu_choice].split("_").last.split("-").last.to_i
      cmd, model, typ = params[:menu_choice].split("_").first.split("-")
      report = @sb[:chart_reports].is_a?(Array) ? report = @sb[:chart_reports][chart_idx] : @sb[:chart_reports]
      data_row = report.table.data[data_idx]
      if @perf_options[:cat]
        top_ids = data_row["assoc_ids_#{report.extras[:group_by_tags][legend_idx]}"][model.downcase.to_sym][:on]
      else
        top_ids = data_row["assoc_ids"][model.downcase.to_sym][:on]
      end
      @perf_options[:top_model] = model.singularize.capitalize
      @perf_options[:top_type] = typ        # day or hour
      @perf_options[:top_ts] = data_row["timestamp"].utc
      @perf_options[:top_ids] = top_ids
    end
    @perf_options[:index] = params[:chart_idx] == "clear" ? nil : params[:chart_idx] if params[:chart_idx]
    @showtype = "performance"
    if request.xml_http_request?  # Is this an Ajax request?
      perf_gen_top_data                   # Generate top data
      return unless @charts               # Return if no charts got created (first time thru async rpt gen)
      render :update do |page|
        page << 'miq_chart_data = ' + {"candu"=>@chart_data}.to_json + ';'
        page.replace("candu_charts_div", :partial=>"layouts/perf_charts", :locals=>{:chart_data=>@chart_data, :chart_set=>"candu"})
        page << Charting.js_load_statement
        page << 'miqSparkle(false);'
      end
    else
      drop_breadcrumb( {:name=>params[:bc],
                        :url=>url_for(:id=>@perf_record.id,
                                      :action=>"perf_top_chart",
                                      :bc=>params[:bc],
                                      :escape => false)
                        } )
#     @spin_msg = "Generating chart data..."
      @ajax_action = "perf_top_chart"
      render :action=>"show"
    end
  end

  # Send the current chart report data in text, CSV, or PDF
  def perf_download
    report = @sb[:chart_reports].class == Array ? @sb[:chart_reports].first : @sb[:chart_reports] # Get the first or only report
    report = perf_remove_report_cols(report)  # Remove cols that are not in the current chart
    filename = @breadcrumbs.last[:name] + " - " + report.title
    disable_client_cache
    case params[:typ]
    when "txt"
      send_data(report.to_text,
        :filename => "#{filename}.txt" )
    when "csv"
      send_data(report.to_csv,
        :filename => "#{filename}.csv" )
    end
  end

  private ############################

  # Initiate the backend refresh of realtime c&u data
  def perf_refresh_data
    assert_privileges("perf_refresh")
    @record = identify_tl_or_perf_record
    @perf_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record
    @perf_record.perf_capture_realtime_now
    add_flash(I18n.t("flash.refresh_cu_data"))
  end

  # Correct any date that is out of the date/range or not allowed in a profile
  def perf_set_or_fix_dates(options)
    # Get start/end dates in selected timezone
    tz = options[:time_profile_tz] || options[:tz]  # Use time profile tz or chosen tz, if no profile tz
    s, e = @perf_record.first_and_last_capture
    if s.nil?
      add_flash(I18n.t("flash.no_utilization_data_available"), :warning)
      @temp[:no_util_data] = true
      return
    end
    sdate = s.in_time_zone(tz)
    edate = e.in_time_zone(tz)
    options[:sdate] = sdate
    options[:edate] = edate

    # Eliminate partial start or end days
    sdate_daily = sdate.hour == 00 ? sdate : sdate + 1.day
    options[:sdate_daily] = sdate_daily
    edate_daily = edate.hour < 23 ? edate - 1.day : edate
    options[:edate_daily] = edate_daily

    if options[:hourly_date] && # Need to clear hourly date if not nil so it will be reset below if
      (options[:hourly_date].to_date < sdate.to_date || options[:hourly_date].to_date > edate.to_date ||  # it is out of range
        (options[:typ] == "Hourly" && options[:time_profile] && !options[:time_profile_days].include?(options[:hourly_date].to_date.wday) ) ) # or not in profile
      options[:hourly_date] = nil
    end
    if options[:daily_date] &&
      (options[:daily_date].to_date < sdate_daily.to_date || options[:daily_date].to_date > edate_daily.to_date)
      options[:daily_date] = nil
    end
    options[:hourly_date] ||= [edate.month, edate.day, edate.year].join("/")
    options[:daily_date] ||= [edate_daily.month, edate_daily.day, edate_daily.year].join("/")

    if options[:typ] == "Hourly" && options[:time_profile]              # If hourly and profile in effect, set hourly date to a valid day in the profile
      options[:skip_days] = [0,1,2,3,4,5,6].delete_if{|d| options[:time_profile_days].include?(d)}.join(",")
      hdate = options[:hourly_date].to_date                             # Start at the currently set hourly date
      6.times do                                                        # Go back up to 6 days (try each weekday)
        break if options[:time_profile_days].include?(hdate.wday)       # If weekday is in the profile, use it
        hdate -= 1.day                                                  # Drop back 1 day and try again
      end
      options[:hourly_date] = [hdate.month, hdate.day, hdate.year].join("/")  # Set the new hourly date
    else
      options[:skip_days] = nil
    end
  end

  # Handle actions for performance chart context menu clicks
  def perf_menu_click
    # Parse the clicked item to get indexes and selection variables
    legend_idx = params[:menu_click].split("_").last.split("-").first.to_i - 1
    data_idx = params[:menu_click].split("_").last.split("-")[-2].to_i - 1
    chart_idx = params[:menu_click].split("_").last.split("-").last.to_i
    cmd, model, typ = params[:menu_click].split("_").first.split("-")

    # Swap in 'Instances' for 'VMs' in AZ breadcrumbs (poor man's cloud/infra split hack)
    bc_model = request.parameters['controller'] == 'availability_zone' && model == 'VMs' ? 'Instances' : model

    report = @sb[:chart_reports].is_a?(Array) ? report = @sb[:chart_reports][chart_idx] : @sb[:chart_reports]
    data_row = report.table.data[data_idx]

    # Use timestamp or statistic_time (metrics vs ontap)
    ts = (data_row["timestamp"] || data_row["statistic_time"]).in_time_zone(@perf_options[:tz])                 # Grab the timestamp from the row in selected tz

    if cmd == "Display" && model == "Current" && typ == "Top"                   # Display the CI selected from a Top chart
      return unless perf_menu_record_valid(data_row["resource_type"], data_row["resource_id"], data_row["resource_name"])
      render :update do |page|
        page.redirect_to( :controller=>data_row["resource_type"].underscore,
                          :action=>"show",
                          :id=>data_row["resource_id"],
                          :escape => false)
      end
      return

    elsif cmd == "Display" && typ == "bytag"  # Display selected resources from a tag chart
      dt = @perf_options[:typ] == "Hourly" ?  "on #{ts.to_date} at #{ts.strftime("%H:%M:%S %Z")}" : "on #{ts.to_date}"
      top_ids = data_row["assoc_ids_#{report.extras[:group_by_tags][legend_idx]}"][model.downcase.to_sym][:on]
      bc_tag =  "#{Classification.find_by_name(@perf_options[:cat]).description}:#{report.extras[:group_by_tag_descriptions][legend_idx]}"
      dt = typ == "tophour" ? "on #{ts.to_date} at #{ts.strftime("%H:%M:%S %Z")}" : "on #{ts.to_date}"
      if top_ids.blank?
        msg = "No #{bc_tag} #{bc_model} were running #{dt}"
      else
        bc = request.parameters["controller"] == "storage" ? "#{bc_model} (#{bc_tag} #{dt})" : "#{bc_model} (#{bc_tag} running #{dt})"
        render :update do |page|
          page.redirect_to( :controller=>model.downcase.singularize,
                            :action=>"show_list",
                            :menu_click=>params[:menu_click],
                            :sb_controller=>request.parameters["controller"],
                            :bc=>bc,
                            :escape => false)
        end
        return
      end

    elsif cmd == "Display"  # Display selected resources
      dt = @perf_options[:typ] == "Hourly" ?  "on #{ts.to_date} at #{ts.strftime("%H:%M:%S %Z")}" : "on #{ts.to_date}"
      state = typ == "on" ? "running" : "stopped"
      if data_row["assoc_ids"][model.downcase.to_sym][typ.to_sym].blank?
        msg = "No #{model} were #{state} #{dt}"
      else
        bc = request.parameters["controller"] == "storage" ? "#{bc_model} #{dt}" : "#{bc_model} #{state} #{dt}"
        render :update do |page|
          page.redirect_to( :controller=>model.downcase.singularize,
                            :action=>"show_list",
                            :menu_click=>params[:menu_click],
                            :sb_controller=>request.parameters["controller"],
                            :bc=>bc,
                            :escape => false)
        end
        return
      end

    elsif cmd == "Timeline" && model == "Current" # Display timeline for the current CI
      @record = identify_tl_or_perf_record
      @perf_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record
      @perf_record = VmOrTemplate.find_by_id(@perf_options[:compare_vm]) unless @perf_options[:compare_vm].nil?
      new_opts = Hash.new
      new_opts[:typ] = typ
      new_opts[:model] = @perf_record.class.base_class.to_s
      dt = typ == "Hourly" ?  "on #{ts.to_date} at #{ts.strftime("%H:%M:%S %Z")}" : "on #{ts.to_date}"
      new_opts[:daily_date] = @perf_options[:daily_date] if typ == "Daily"
      new_opts[:hourly_date] = [ts.month, ts.day, ts.year].join("/") if typ == "Hourly"
      new_opts[:tl_show_options] = Array.new
      new_opts[:tl_show_options].push(["Management Events","timeline"])
      new_opts[:tl_show_options].push(["Policy Events","policy_timeline"])
      new_opts[:tl_show] = "timeline"
      session[(request.parameters["controller"] +"_tl").to_sym] ||= Hash.new
      session[(request.parameters["controller"] +"_tl").to_sym].merge!(new_opts)
      f, l = @perf_record.first_and_last_event
      if f.nil?
        msg = "No events available for this #{new_opts[:model] == "EmsCluster" ? "Cluster" : new_opts[:model]}"
      elsif @record.kind_of?(MiqServer) # For server charts in OPS
        change_tab("a6")                # Switch to the Timelines tab
        return
      else
        if @explorer
          @_params[:id] = @perf_record.id
          @_params[:refresh] = "n"
          show_timeline
        else
          render :update do |page|
            page.redirect_to( :id=>@perf_record.id,
                              :action=>"show",
                              :display=>"timeline",
                              :controller=>model_to_controller(@perf_record),
                              :refresh=>"n",
                              :escape => false)
          end
        end
        return
      end

    elsif cmd == "Timeline" && model == "Selected"  # Display timeline for the selected CI
      return unless @record = perf_menu_record_valid(data_row["resource_type"], data_row["resource_id"], data_row["resource_name"])
      new_opts = Hash.new
      new_opts[:typ] = typ
      new_opts[:model] = data_row["resource_type"]
      dt = typ == "Hourly" ?  "on #{ts.to_date} at #{ts.strftime("%H:%M:%S %Z")}" : "on #{ts.to_date}"
      new_opts[:daily_date] = @perf_options[:daily_date] if typ == "Daily"
      new_opts[:hourly_date] = [ts.month, ts.day, ts.year].join("/") if typ == "Hourly"
      new_opts[:tl_show_options] = Array.new
      new_opts[:tl_show_options].push(["Management Events","timeline"])
      new_opts[:tl_show_options].push(["Policy Events","policy_timeline"])
      new_opts[:tl_show] = "timeline"
      controller = new_opts[:model].underscore
      session[(controller +"_tl").to_sym] ||= Hash.new
      session[(controller +"_tl").to_sym].merge!(new_opts)
      f, l = data_row["resource_type"].constantize.find(data_row["resource_id"]).first_and_last_event
      if f.nil?
        msg = "No events available for this #{model == "EmsCluster" ? "Cluster" : model}"
      elsif @record.kind_of?(MiqServer) # For server charts in OPS
        change_tab("a6")                # Switch to the Timelines tab
        return
      else
        if @explorer
          @_params[:id] = data_row["resource_id"]
          @_params[:refresh] = "n"
          show_timeline
        else
          render :update do |page|
            if data_row["resource_type"] == "VmOrTemplate"
              prefix = X_TREE_NODE_PREFIXES.invert[@record.class.base_model.to_s]
              tree_node_id = "#{prefix}-#{@record.id}"  # Build the tree node id
              session[:exp_parms] = {:display=>"timeline", :refresh=>"n", :id=>tree_node_id}
              page.redirect_to(:controller=>data_row["resource_type"].underscore.downcase.singularize,
                               :action=>"explorer")
            else
              page.redirect_to( :controller=>data_row["resource_type"].underscore.downcase.singularize,
                                :action=>"show_timeline",
                                :id=>data_row["resource_id"],
                                :refresh=>"n",
                                :escape => false)
            end
          end
        end
        return
      end

    elsif cmd == "Chart" && model == "Current" && typ == "Hourly" # Create hourly chart for selected day
      @record = identify_tl_or_perf_record
      @perf_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record
      @perf_options[:typ] = "Hourly"
      @perf_options[:hourly_date] = [ts.month, ts.day, ts.year].join("/")

      perf_set_or_fix_dates(@perf_options)  unless params[:task_id] # Set dates if first time thru
      perf_gen_data(refresh="n")
      return unless @temp[:charts]      # Return if no charts got created (first time thru async rpt gen)

      render :update do |page|
        if @temp[:parent_chart_data]
          page << 'miq_chart_data = ' + {"candu"=>@temp[:chart_data], "parent"=>@temp[:parent_chart_data]}.to_json + ';'
        elsif @temp[:parent_chart_data]
          page << 'miq_chart_data = ' + {"candu"=>@temp[:chart_data], "compare_vm"=>@temp[:compare_vm_chart_data]}.to_json + ';'
        else
          page << 'miq_chart_data = ' + {"candu"=>@temp[:chart_data]}.to_json + ';'
        end
        page.replace("perf_options_div", :partial=>"layouts/perf_options")
        page.replace("candu_charts_div", :partial=>"layouts/perf_charts", :locals=>{:chart_data=>@temp[:chart_data], :chart_set=>"candu"})
        page << "miq_cal_dateFrom = new Date(#{@perf_options[:sdate].year},#{@perf_options[:sdate].month-1},#{@perf_options[:sdate].day});"
        page << "miq_cal_dateTo = new Date(#{@perf_options[:edate].year},#{@perf_options[:edate].month-1},#{@perf_options[:edate].day});"
        if @perf_options[:skip_days]
          page << "miq_cal_skipDays = '#{@perf_options[:skip_days]}';"
        else
          page << "miq_cal_skipDays = null;"
        end
        page << 'miqBuildCalendar();'
        page << Charting.js_load_statement
        page << 'miqSparkle(false);'
      end
      return

    elsif cmd == "Chart" && model == "Current" && typ == "Daily"  # Go back to the daily chart
      @record = identify_tl_or_perf_record
      @perf_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record
      @perf_options[:typ] = "Daily"

      perf_set_or_fix_dates(@perf_options)  unless params[:task_id] # Set dates if first time thru
      perf_gen_data(refresh="n")
      return unless @temp[:charts]        # Return if no charts got created (first time thru async rpt gen)

      render :update do |page|
        if @temp[:parent_chart_data]
          page << 'miq_chart_data = ' + {"candu"=>@temp[:chart_data], "parent"=>@temp[:parent_chart_data]}.to_json + ';'
        else
          page << 'miq_chart_data = ' + {"candu"=>@temp[:chart_data]}.to_json + ';'
        end
        page.replace("perf_options_div", :partial=>"layouts/perf_options")
        page.replace("candu_charts_div", :partial=>"layouts/perf_charts", :locals=>{:chart_data=>@temp[:chart_data], :chart_set=>"candu"})
        page << "miq_cal_dateFrom = new Date(#{@perf_options[:sdate_daily].year},#{@perf_options[:sdate_daily].month-1},#{@perf_options[:sdate_daily].day});"
        page << "miq_cal_dateTo = new Date(#{@perf_options[:edate_daily].year},#{@perf_options[:edate_daily].month-1},#{@perf_options[:edate_daily].day});"
        if @perf_options[:skip_days]
          page << "miq_cal_skipDays = '#{@perf_options[:skip_days]}';"
        else
          page << "miq_cal_skipDays = null;"
        end
        page << 'miqBuildCalendar();'
        page << Charting.js_load_statement
        page << 'miqSparkle(false);'
      end
      return

    elsif cmd == "Chart" && model == "Selected"                             # Create daily/hourly chart for selected CI
      return unless @record = perf_menu_record_valid(data_row["resource_type"], data_row["resource_id"], data_row["resource_name"])
      new_opts = Hash.new

      # Copy general items from the current perf_options
      new_opts[:index] = @perf_options[:index]
      new_opts[:tz] = @perf_options[:tz]
      new_opts[:time_profile] = @perf_options[:time_profile]
      new_opts[:time_profile_days] = @perf_options[:time_profile_days]
      new_opts[:time_profile_tz] = @perf_options[:time_profile_tz]

      # Set new perf options based on what was selected
      new_opts[:model] = data_row["resource_type"]
      new_opts[:typ] = typ
      new_opts[:daily_date] = @perf_options[:daily_date] if typ == "Daily"
      new_opts[:days] = @perf_options[:days] if typ == "Daily"
      new_opts[:hourly_date] = [ts.month, ts.day, ts.year].join("/") if typ == "Hourly"

      # Set the perf options in the selected controller's sandbox
      cont = data_row["resource_type"].underscore.downcase.to_sym
      session[:sandboxes][cont] ||= Hash.new
      session[:sandboxes][cont][:perf_options] ||= Hash.new
      session[:sandboxes][cont][:perf_options].merge!(new_opts)

      render :update do |page|
        if data_row["resource_type"] == "VmOrTemplate"
          prefix = X_TREE_NODE_PREFIXES.invert[@record.class.base_model.to_s]
          tree_node_id = "#{prefix}-#{@record.id}"  # Build the tree node id
          session[:exp_parms] = {:display=>"performance", :refresh=>"n", :id=>tree_node_id}
          page.redirect_to(:controller=>data_row["resource_type"].underscore.downcase.singularize,
                           :action=>"explorer")
        else
          page.redirect_to(:controller=>data_row["resource_type"].underscore.downcase.singularize,
                           :action=>"show",
                           :id=>data_row["resource_id"],
                           :display=>"performance",
                           :refresh=>"n",
                           :escape=>false)
        end
      end
      return

    elsif cmd == "Chart" && typ.starts_with?("top") && @perf_options[:cat]  # Create top chart for selected timestamp/model by tag
      @record = identify_tl_or_perf_record
      @perf_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record
      top_ids = data_row["assoc_ids_#{report.extras[:group_by_tags][legend_idx]}"][model.downcase.to_sym][:on]
      bc_tag =  "#{Classification.find_by_name(@perf_options[:cat]).description}:#{report.extras[:group_by_tag_descriptions][legend_idx]}"
      dt = typ == "tophour" ? "on #{ts.to_date} at #{ts.strftime("%H:%M:%S %Z")}" : "on #{ts.to_date}"
      if top_ids.blank?
        msg = "No #{bc_tag} #{bc_model} were running #{dt}"
      else
        render :update do |page|
          page.redirect_to( :id=>@perf_record.id,
                            :action=>"perf_top_chart",
                            :menu_choice=>params[:menu_click],
                            :bc=>"#{@perf_record.name} top #{bc_model} (#{bc_tag} #{dt})",
                            :escape => false)
        end
        return
      end

    elsif cmd == "Chart" && typ.starts_with?("top")                         # Create top chart for selected timestamp/model
      @record = identify_tl_or_perf_record
      @perf_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record
      top_ids = data_row["assoc_ids"][model.downcase.to_sym][:on]
      dt = typ == "tophour" ? "on #{ts.to_date} at #{ts.strftime("%H:%M:%S %Z")}" : "on #{ts.to_date}"
      if top_ids.blank?
        msg = "No #{model} were running #{dt}"
      else
        render :update do |page|
          page.redirect_to( :id=>@perf_record.id,
                            :action=>"perf_top_chart",
                            :menu_choice=>params[:menu_click],
                            :bc=>"#{@perf_record.name} top #{bc_model} (#{dt})",
                            :escape => false)
        end
        return
      end

    else
      msg = "Chart menu selection not yet implemented"
    end

    msg ? add_flash(msg, :warning) : add_flash(I18n.t("flash.unknown_error", :error))
    render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page << "miqSparkle(false);"
    end
  end

  # Send error message if record is found and authorized, else return the record
  def perf_menu_record_valid(model, id, resource_name)
    rec = find_by_model_and_id_check_rbac(model, id, resource_name)
    unless @flash_array.blank?
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page << "miqSparkle(false);"
      end
      return false
    end
    return rec  # Record is found and authorized
  end

  # Load a chart miq_report object from YML
  def perf_get_chart_rpt(chart_rpt)
    return MiqReport.new(YAML::load(File.open("#{CHARTS_REPORTS_FOLDER}/#{chart_rpt.to_s}.yaml")))
  end

  # Load a chart layout from YML
  def perf_get_chart_layout(layout, fname = nil)
    if fname
      charts = YAML::load(File.open("#{CHARTS_LAYOUTS_FOLDER}/#{layout.to_s}/#{fname.to_s}.yaml"))
    else
      charts = YAML::load(File.open("#{CHARTS_LAYOUTS_FOLDER}/#{layout.to_s}.yaml"))
    end
    charts.delete_if do |c|
      c.is_a?(Hash) && c[:applies_to_method] && @perf_record &&
        @perf_record.respond_to?(c[:applies_to_method]) &&
        !@perf_record.send(c[:applies_to_method].to_sym)
    end
    @perf_options[:index] = nil unless @perf_options[:index].nil? || charts[@perf_options[:index].to_i]
    return charts
  end

  # Init options for performance charts
  def perf_gen_init_options(refresh = nil)
    @perf_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record
    unless (refresh == "n" || params[:refresh] == "n")
      @perf_options = Hash.new
      tzs = TimeProfile.rollup_daily_metrics.all_timezones
      @perf_options[:tz_daily] = tzs.include?(session[:user_tz]) ? session[:user_tz] : tzs.first
      @perf_options[:typ] = "Daily"
      # TODO: Remove next line once daily is available for Vmdb tables
      @perf_options[:typ] = "Hourly" if @perf_record.class.name.starts_with?("Vmdb")
      @perf_options[:days] = "7"
      @perf_options[:rt_minutes] = 15.minutes
      @perf_options[:model] = @perf_record.is_a?(MiqCimInstance) ? @perf_record.class.to_s : @perf_record.class.base_class.to_s
    end
    @perf_options[:rt_minutes] ||= 15.minutes
    @perf_options[:cats] ||= perf_build_cats(@perf_options[:model]) if ["EmsCluster", "Host", "Storage", "AvailabilityZone"].include?(@perf_options[:model])
    if ["Storage"].include?(@perf_options[:model]) && @perf_options[:typ] == "Daily"
      @perf_options[:vmtypes] ||= [ ["<All>", "<All>"],
                                    ["Managed/Registered", "registered"],
                                    ["Managed/Unregistered", "unregistered"],
                                    ["Not Managed", "unmanaged"]
                                  ]
    else
      @perf_options[:vmtypes] = nil
    end

    get_time_profiles(@perf_record) # Get time profiles list (global and user specific). Pass record so that profiles can be limited to its region.
    # Get the time zone from the time profile, if one is in use
    if @perf_options[:time_profile]
      tp = TimeProfile.find_by_id(@perf_options[:time_profile])
      set_time_profile_vars(tp, @perf_options)
    else
      set_time_profile_vars(selected_time_profile_for_pull_down, @perf_options)
    end

    # Get start/end dates in selected timezone, but only right before displaying the chart options screen
    perf_set_or_fix_dates(@perf_options) if params[:action] == "perf_chart_chooser"

    @perf_options[:days] ||= "7"
    @perf_options[:ght_type] ||= "hybrid"
    @perf_options[:chart_type] = :performance

    name = @perf_record.respond_to?(:evm_display_name) ? @perf_record.evm_display_name : @perf_record.name
    if @perf_options[:cat]
      drop_breadcrumb( {:name=>"#{name} Capacity & Utilization (by #{@perf_options[:cats][@perf_options[:cat_model] + ":" + @perf_options[:cat]]})",
                        :url=>url_for(:action=>"show", :id=>@perf_record,:display=>"performance", :refresh=>"n") } )
    else
      drop_breadcrumb( {:name=>"#{name} Capacity & Utilization",
                        :url=>url_for(:action=>"show", :id=>@perf_record,:display=>"performance", :refresh=>"n") } )
    end
    @ajax_action = "perf_chart_chooser"
  end

  # Generate performance data for a model's charts
  def perf_gen_data(refresh = nil)
    if @perf_options[:cat]
      drop_breadcrumb( {:name=>"#{@perf_record.name} Capacity & Utilization (by #{@perf_options[:cats][@perf_options[:cat_model] + ":" + @perf_options[:cat]]})",
                        :url=>url_for(:action=>"show", :id=>@perf_record,:display=>"performance", :refresh=>"n") } )
    else
      drop_breadcrumb( {:name=>"#{@perf_record.name} Capacity & Utilization",
                        :url=>url_for(:action=>"show", :id=>@perf_record,:display=>"performance", :refresh=>"n") } )
    end

    unless @perf_options[:typ] == "realtime"
      if @perf_options[:cat]                                      # If a category was chosen, generate charts by tag
        perf_gen_tag_data
        return
      end
    end

    unless params[:task_id]                                     # First time thru, kick off the report generate task
      perf_gen_data_before_wait
    else
      perf_gen_data_after_wait
    end
  end

  # Generate performance data for a model's charts - kick off report task
  def perf_gen_data_before_wait
    interval_type = @perf_options[:typ].downcase
    case interval_type
    when "hourly", "daily"

      # Set from/to datetimes
      if interval_type == "hourly"
        from_dt = create_time_in_utc(@perf_options[:hourly_date] + " 00", @perf_options[:tz]) # Get tz 12am in UTC
        to_dt = create_time_in_utc(@perf_options[:hourly_date] + " 23", @perf_options[:tz])   # Get tz 11pm in UTC
      elsif interval_type == "daily"
        f = Date.parse(@perf_options[:daily_date]) - (@perf_options[:days].to_i - 1)
        st = @perf_options[:sdate_daily]
        s = Date.parse("#{st.year}/#{st.month}/#{st.day}")
        f = s if f < s                                      # Use later date
        from_dt = create_time_in_utc("#{f.year}/#{f.month}/#{f.day} 00", @perf_options[:tz])  # Get tz 12am in UTC
        to_dt = create_time_in_utc("#{@perf_options[:daily_date]} 23", @perf_options[:tz])    # Get tz 11pm in UTC
      end

      # Get the report definition (yaml) and set the where clause based on the record type
      if @perf_record.is_a?(MiqCimInstance)
        rpt = perf_get_chart_rpt(@perf_options[:model].underscore)
        if interval_type == "hourly"
          rpt.where_clause =  [ "miq_cim_instance_id = ? and statistic_time >= ? and statistic_time <= ? and rollup_type = ?",
                                @perf_record.id,
                                from_dt,
                                to_dt,
                                interval_type]
        elsif interval_type == "daily"
          tz = @perf_options["tz#{@perf_options[:typ] == "Daily" ? "_daily" : ""}".to_sym]
          tp = @perf_options[:time_profile] ||
               TimeProfile.rollup_daily_metrics.find_all_with_entire_tz.detect {|p| p.tz_or_default == tz}.id
          rpt.where_clause =  [ "miq_cim_instance_id = ? and statistic_time >= ? and statistic_time <= ? and rollup_type = ? and time_profile_id = ?",
                                 @perf_record.id,
                                 from_dt,
                                 to_dt,
                                 interval_type,
                                 tp]
        end
      elsif @perf_record.is_a?(VmdbDatabase)
        rpt = perf_get_chart_rpt(@perf_options[:model].underscore)
        rpt.where_clause =  [ "vmdb_database_id = ? and timestamp >= ? and timestamp <= ? and capture_interval_name = ?",
                              @perf_record.id,
                              from_dt,
                              to_dt,
                              interval_type]
      elsif @perf_record.is_a?(VmdbTable)
        rpt = perf_get_chart_rpt(@perf_options[:model].underscore)
        rpt.where_clause =  [ "resource_type = ? and resource_id = ? and timestamp >= ? and timestamp <= ? and capture_interval_name = ?",
                              @perf_options[:model],
                              @perf_record.id,
                              from_dt,
                              to_dt,
                              interval_type]
      else  # Doing VIM performance on a normal CI
        suffix = @perf_record.is_a?(AvailabilityZone) ? "_cloud" : "" # Get special cloud version with 'Instances' headers
        rpt = perf_get_chart_rpt("vim_perf_#{interval_type}#{suffix}")
        rpt.where_clause =  [ "resource_type = ? and resource_id = ? and timestamp >= ? and timestamp <= ? and capture_interval_name = ?",
                              @perf_options[:model],
                              @perf_record.id,
                              from_dt,
                              to_dt,
                              interval_type]
      end
      rpt.tz = @perf_options[:tz]
      rpt.time_profile_id = @perf_options[:time_profile]

    when "realtime"
      f, to_dt = @perf_record.first_and_last_capture("realtime")
      from_dt = to_dt.nil? ? nil : to_dt - @perf_options[:rt_minutes]
      rpt = perf_get_chart_rpt("vim_perf_realtime")
      rpt.tz = @perf_options[:tz]
      rpt.extras = Hash.new
      rpt.extras[:realtime] = true
      @perf_options[:range] = to_dt.nil? ? nil :
                              "#{format_timezone(from_dt,@perf_options[:tz],"datetime")} to #{format_timezone(to_dt,@perf_options[:tz],"gtl")}"
      rpt.where_clause =  [ "resource_type = ? and resource_id = ? and timestamp >= ? and timestamp <= ? and capture_interval_name = ?",
                            @perf_options[:model],
                            @perf_record.id,
                            from_dt,
                            to_dt,
                            "realtime"]

#### To do - Uncomment to ask for long term averages
#       rpt.db_options ||= Hash.new
#       rpt.db_options[:long_term_averages] = Hash.new  # Request that averages get computed
####

    end
    rpts = [rpt]
    if perf_parent?                               # Build the parent report, if asked for
      p_rpt = Marshal::load(Marshal.dump(rpt))    # Deep clone the main report
      p_rpt.where_clause[1] = @perf_options[:parent]
      p_rpt.where_clause[2] = @perf_record.send(VALID_PERF_PARENTS[@perf_options[:parent]]).id
      rpts.push(p_rpt)
    elsif perf_compare_vm?                        # Build the compare to VM report, i0f asked for
      c_rpt = perf_get_chart_rpt("vim_perf_#{@perf_options[:typ].downcase}")
      c_rpt.tz = @perf_options[:tz]
      c_rpt.time_profile_id = @perf_options[:time_profile]
      c_rpt.where_clause =  [ "resource_type = ? and resource_id = ? and timestamp >= ? and timestamp <= ?",
                            "VmOrTemplate",
                            @perf_options[:compare_vm],
                            from_dt,
                            to_dt ]
      rpts.push(c_rpt)
    end

### TODO: Uncomment following block for performance.  Need to fix, was causing second parent chart to have no cols.
    # If only looking at 1 chart, trim report columns for less daily rollups
#     if @perf_options[:index] && @perf_options[:typ] = "Daily"
#       chart_layouts = perf_get_chart_layout("daily_perf_charts")
#       chart = chart_layouts[@perf_options[:model].to_sym][@perf_options[:index].to_i]
#       perf_trim_report_cols(rpt, chart)
#       if perf_parent?                               # Trim the parent report, if asked for
#         chart = chart_layouts[("Parent-" + @perf_options[:parent]).to_sym][@perf_options[:index].to_i]
#         perf_trim_report_cols(p_rpt, chart)
#       end
#     end

    initiate_wait_for_task(:task_id => MiqReport.async_generate_tables(:reports => rpts, :userid => session[:userid]))
  end

  # Generate performance data for a model's charts - generate charts from report task results
  def perf_gen_data_after_wait
    miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
    rpt = miq_task.task_results.first             # Grab the only report in the array of reports returned
    p_rpt = miq_task.task_results[1] if perf_parent?  # Grab the parent report in the array of reports returned
    c_rpt = miq_task.task_results[1] if perf_compare_vm?  # Grab the compare VM report in the array of reports returned
    miq_task.destroy                              # Get rid of the task and results

    @temp[:charts], @temp[:chart_data] = perf_gen_charts(rpt, @perf_options)
    if perf_parent?
      @temp[:parent_charts], @temp[:parent_chart_data] =
        perf_gen_charts(p_rpt, @perf_options.merge({:model=>"Parent-#{@perf_options[:parent]}"}))
    elsif perf_compare_vm?
      @compare_vm = VmOrTemplate.find_by_id(@perf_options[:compare_vm]) # Get rec for view to use
      @temp[:compare_vm_charts], @temp[:compare_vm_chart_data] =
        perf_gen_charts(c_rpt, @perf_options.merge({:model=>"VmOrTemplate"}))
    end

    @sb[:chart_reports] = rpt           # Hang on to the report data for these charts

    ### TODO: Get rid of all references to @charts/@chart_data, change to use @temp hash
#   @charts = @temp[:charts]
#   @chart_data = @temp[:chart_data]

    @html = perf_report_to_html
    @p_html = perf_report_to_html(p_rpt, @temp[:parent_charts][0]) if perf_parent?
    @c_html = perf_report_to_html(c_rpt, @temp[:compare_vm_charts][0]) if perf_compare_vm? && !@temp[:compare_vm_charts].empty?
  end

  # Return the column in the chart that starts with "trend_"
  def perf_get_chart_trendcol(chart)
    chart[:columns].each do |c|
      return c if c.starts_with?("trend_")
    end
    return nil
  end

  # Remove columns from chart based on model and/or options
  def perf_remove_chart_cols(chart)
    if @perf_options[:model] == "Host" && @perf_record.owning_cluster != nil
      chart[:columns].delete_if{|col| col.include?("reserved")}
      chart[:trends].delete_if{|trend| trend.include?("reserved")} if chart[:trends]
    end
    if chart[:title].include?("by Type")
      chart[:columns].delete_if{|col| !col.include?("_" + @perf_options[:vmtype])} if @perf_options[:vmtype] && @perf_options[:vmtype] != "<All>"
    end
  end

  # Generate performance data by tag for a model's charts
  def perf_gen_tag_data
    @perf_options[:chart_type] = :performance
    unless params[:task_id]                       # First time thru, kick off the report generate task
      perf_gen_tag_data_before_wait
    else
      perf_gen_tag_data_after_wait
    end
  end

  # Generate performance data by tag - kick off report task
  def perf_gen_tag_data_before_wait
    case @perf_options[:typ]
    when "Hourly"
      from_dt = create_time_in_utc(@perf_options[:hourly_date] + " 00:00:00", @perf_options[:tz]) # Get tz 12am in UTC
      to_dt = create_time_in_utc(@perf_options[:hourly_date] + " 23:59:59", @perf_options[:tz])   # Get tz 11:59pm in UTC
      rpt = perf_get_chart_rpt("vim_perf_tag_hourly")
      rpt.performance = {:group_by_category => @perf_options[:cat]}
      rpt.tz = @perf_options[:tz]
      rpt.time_profile_id = @perf_options[:time_profile]
      rpt.where_clause =  [ "resource_type = ? and resource_id = ? and timestamp >= ? and timestamp <= ? and capture_interval_name = ?",
                            @perf_record.class.base_class.name,
                            @perf_record.id,
                            from_dt,
                            to_dt,
                            'hourly']
    when "Daily"
      f = Date.parse(@perf_options[:daily_date]) - (@perf_options[:days].to_i - 1)
      from_dt = create_time_in_utc("#{f.year}/#{f.month}/#{f.day} 00", @perf_options[:tz])  # Get tz 12am in UTC
      to_dt = create_time_in_utc("#{@perf_options[:daily_date]} 23", @perf_options[:tz])    # Get tz 11pm in UTC
      rpt = perf_get_chart_rpt("vim_perf_tag_daily")
      rpt.time_profile_id = @perf_options[:time_profile]
      chart_layout = perf_get_chart_layout("daily_tag_charts", @perf_options[:model]) if @perf_options[:index]
      if @perf_options[:index]                    # If only looking at 1 chart, trim report columns for less daily rollups
        chart = chart_layout[@perf_options[:index].to_i]
        perf_trim_report_cols(rpt, chart)
      end
      rpt.tz = @perf_options[:tz]
      rpt.performance = {:group_by_category => @perf_options[:cat]}
      rpt.where_clause =  [ "resource_type = ? and resource_id = ? and timestamp >= ? and timestamp <= ?",
                            @perf_record.class.base_class.name,
                            @perf_record.id,
                            from_dt,
                            to_dt ]
    end
    initiate_wait_for_task(:task_id => rpt.async_generate_table(
      :userid     => session[:userid],
      :session_id => request.session_options[:id],
      :cat_model  => @perf_options[:cat_model],
      :mode       => "charts")
    )
  end

  # Generate performance data by tag - generate charts from report task results
  def perf_gen_tag_data_after_wait
    miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
    rpt = miq_task.miq_report_result.report_results # Grab the report object from the blob
    miq_task.destroy                              # Get rid of the task and results

    @charts = Array.new
    @chart_data = Array.new
    cat_desc = Classification.find_by_name(@perf_options[:cat]).description
    case @perf_options[:typ]
    when "Hourly"
      chart_layout = perf_get_chart_layout("hourly_tag_charts", @perf_options[:model])
      unless @perf_options[:index]            # Gen all charts if no index present
        chart_layout.each_with_index do |chart, idx|
          chart[:menu].delete_if{|m| m.include?(@perf_options[:cat_model] == "Host" ? "VMs for" : "Hosts for")} # Remove opposite menu items
          chart[:menu].each{|m| m.gsub!(/<cat>/, cat_desc + " <series>")}           # Substitue category description + ':<series>' into menus
          col = chart[:columns].first                                               # Grab the first (and should be only) chart column
          chart[:columns] = rpt.extras[:group_by_tags].collect{|t| col + "_" + t}   # Create the new chart columns for each tag
          options = chart.merge({:zoom_url=>perf_zoom_url("perf_chart_chooser", idx.to_s),
                                :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
                                :axis_skip=>3
                                })
          @chart_data.push(perf_gen_chart(rpt, options).merge({:menu=>chart[:menu]}))
          chart[:title] = rpt.title           # Grab title from chart in case formatting added units
          @charts.push(chart)
        end
      else                                    # Gen chart based on index
        chart = chart_layout[@perf_options[:index].to_i]
        chart[:menu].delete_if{|m| m.include?(@perf_options[:cat_model] == "Host" ? "VMs for" : "Hosts for")} # Remove opposite menu items
        chart[:menu].each{|m| m.gsub!(/<cat>/, cat_desc + " <series>")}           # Substitue category description + ':<series>' into menus
        col = chart[:columns].first                                               # Grab the first (and should be only) chart column
        chart[:columns] = rpt.extras[:group_by_tags].collect{|t| col + "_" + t}   # Create the new chart columns for each tag
        options = chart.merge({:zoom_url=>perf_zoom_url("perf_chart_chooser", "clear"),
                              :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
                              :axis_skip=>3,
                              :width=>1000, :height=>700
                              })
        @chart_data.push(perf_gen_chart(rpt, options).merge({:menu=>chart[:menu]}))
        chart[:title] = rpt.title           # Grab title from chart in case formatting added units
        @charts.push(chart)
      end
    when "Daily"
      chart_layout = perf_get_chart_layout("daily_tag_charts", @perf_options[:model])
      unless @perf_options[:index]
        chart_layout.each_with_index do |chart, idx|
          chart[:menu].delete_if{|m| m.include?(@perf_options[:cat_model] == "Host" ? "VMs for" : "Hosts for")} # Remove opposite menu items
          chart[:menu].each{|m| m.gsub!(/<cat>/, cat_desc + " <series>")}           # Substitue category description + ':<series>' into menus
          col = chart[:columns].first                                               # Grab the first (and should be only) chart column
          chart[:columns] = rpt.extras[:group_by_tags].collect{|t| col + "_" + t}   # Create the new chart columns for each tag
          options = chart.merge({:zoom_url=>perf_zoom_url("perf_chart_chooser", idx.to_s),
                                :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
                                :axis_skip=>3
                                })
          if chart[:trends] && rpt.extras && rpt.extras[:trend]
            trendcol = perf_get_chart_trendcol(chart)
            options[:trendtip] = chart[:trends].collect{|t| t.split(":").last + ": " +
                                  rpt.extras[:trend][trendcol + "|" + t.split(":").first]}.join("\r") unless trendcol.nil?
          end
          @chart_data.push(perf_gen_chart(rpt, options).merge({:menu=>chart[:menu]}))
          chart[:title] = rpt.title           # Grab title from chart in case formatting added units
          @charts.push(chart)
        end
      else
        chart = chart_layout[@perf_options[:index].to_i]
        chart[:menu].delete_if{|m| m.include?(@perf_options[:cat_model] == "Host" ? "VMs for" : "Hosts for")} # Remove opposite menu items
        chart[:menu].each{|m| m.gsub!(/<cat>/, cat_desc + " <series>")}           # Substitue category description + ':<series>' into menus
        col = chart[:columns].first                                               # Grab the first (and should be only) chart column
        chart[:columns] = rpt.extras[:group_by_tags].collect{|t| col + "_" + t}   # Create the new chart columns for each tag
        options = chart.merge({:zoom_url=>perf_zoom_url("perf_chart_chooser", "clear"),
                              :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
                              :axis_skip=>3,
                              :width=>1000, :height=>700
                              })
        if chart[:trends] && rpt.extras && rpt.extras[:trend]
          trendcol = perf_get_chart_trendcol(chart)
          options[:trendtip] = chart[:trends].collect{|t| t.split(":").last + ": " +
                                rpt.extras[:trend][trendcol + "|" + t.split(":").first]}.join("\r") unless trendcol.nil?
        end
        @chart_data.push(perf_gen_chart(rpt, options).merge({:menu=>chart[:menu]}))
        chart[:title] = rpt.title           # Grab title from chart in case formatting added units
        @charts.push(chart)
      end
    end
    @sb[:chart_reports] = rpt           # Hang on to the report data for these charts
    @temp[:charts] = @charts
    @temp[:chart_data] = @chart_data
    @html = perf_report_to_html
  end

  # Generate top 10 chart data
  def perf_gen_top_data
    unless params[:task_id]                       # First time thru, kick off the report generate task
      perf_gen_top_data_before_wait
    else
      perf_gen_top_data_after_wait
    end
  end

  # Generate top 10 chart data - kick off report task
  def perf_gen_top_data_before_wait
    @perf_options[:ght_type] ||= "hybrid"
    @perf_options[:chart_type] = :performance
    cont_plus_model = request.parameters["controller"] + "-" + @perf_options[:top_model]
    metric_model = @perf_options[:top_model] == "Vm" ? "VmOrTemplate" : @perf_options[:top_model]
    rpts = Array.new                            # Store all reports for the async task to work on
    case @perf_options[:top_type]
    when "topday"
      chart_layout = perf_get_chart_layout("day_top_charts", cont_plus_model)
      unless @perf_options[:index]              # Gen all charts if no index present
        chart_layout.each_with_index do |chart, idx|
          next if chart.nil?
          rpt = perf_get_chart_rpt("vim_perf_topday")
          rpt.db = "VimPerformanceDaily"
          rpt.tz = @perf_options[:tz]
          rpt.time_profile_id = @perf_options[:time_profile]
          rpt.where_clause = ["resource_type = ? and resource_id IN (?) and timestamp >= ? and timestamp < ?",
                              metric_model,
                              @perf_options[:top_ids],
                              @perf_options[:top_ts].utc,
                              @perf_options[:top_ts].utc + 1.day]
          rpts.push(rpt)
        end
      else                                      # Gen chart based on index
        rpt = perf_get_chart_rpt("vim_perf_topday")
        rpt.db = "VimPerformanceDaily"
        rpt.tz = @perf_options[:tz]
        rpt.time_profile_id = @perf_options[:time_profile]
        rpt.where_clause = ["resource_type = ? and resource_id IN (?) and timestamp >= ? and timestamp < ?",
                            metric_model,
                            @perf_options[:top_ids],
                            @perf_options[:top_ts].utc,
                            @perf_options[:top_ts].utc + 1.day]
        rpts.push(rpt)
      end
    when "tophour"
      chart_layout = perf_get_chart_layout("hour_top_charts", cont_plus_model)
      unless @perf_options[:index]            # Gen all charts if no index present
        chart_layout.each_with_index do |chart, idx|
          next if chart.nil?
          rpt = perf_get_chart_rpt("vim_perf_tophour")
          rpt.db = "MetricRollup"
          rpt.tz = @perf_options[:tz]
          rpt.time_profile_id = @perf_options[:time_profile]
          rpt.where_clause = ["resource_type = ? and resource_id IN (?) and timestamp = ? and capture_interval_name = ?",
                              metric_model,
                              @perf_options[:top_ids],
                              @perf_options[:top_ts].utc,
                              'hourly']
          rpts.push(rpt)
        end
      else                                    # Gen chart based on index
        rpt = perf_get_chart_rpt("vim_perf_tophour")
        rpt.db = "MetricRollup"
        rpt.tz = @perf_options[:tz]
        rpt.time_profile_id = @perf_options[:time_profile]
        rpt.where_clause = ["resource_type = ? and resource_id IN (?) and timestamp = ? and capture_interval_name = ?",
                            metric_model,
                            @perf_options[:top_ids],
                            @perf_options[:top_ts].utc,
                            'hourly']
        rpts.push(rpt)
      end
    end
    if rpts.length == 1
      initiate_wait_for_task(:task_id => rpts.first.async_generate_table(
        :userid     => session[:userid],
        :session_id => request.session_options[:id],
        :mode       => "charts"))
    else
      initiate_wait_for_task(:task_id => MiqReport.async_generate_tables(:reports => rpts, :userid => session[:userid]))
    end
  end

  # Generate top 10 chart data - generate charts from report task results
  def perf_gen_top_data_after_wait
    miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
    if miq_task.task_results.is_a?(Array)
      rpts = miq_task.task_results.reverse        # Grab the array of report objects (reversed so reports can be popped off)
    else
      rpt = miq_task.miq_report_result.report_results # Grab the report object from the blob
    end
    miq_task.destroy                              # Get rid of the task and results

    @chart_reports = Array.new
    @charts = Array.new
    @chart_data = Array.new

    @perf_options[:ght_type] ||= "hybrid"
    @perf_options[:chart_type] = :performance
    cont_plus_model = request.parameters["controller"] + "-" + @perf_options[:top_model]
    case @perf_options[:top_type]
    when "topday"
      chart_layouts = perf_get_chart_layout("day_top_charts", cont_plus_model)
      unless @perf_options[:index]            # Gen all charts if no index present
        chart_layouts.each_with_index do |chart, idx|
          next if chart.nil?
          options = chart.merge({:zoom_url=>perf_zoom_url("perf_top_chart", idx.to_s),
                                :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )"
                                })
          rpt = rpts.pop                      # Get the next report object from the array
          @chart_data.push(perf_gen_chart(rpt, options).merge({:menu=>chart[:menu]}))
          chart[:title] = rpt.title           # Grab title from chart in case formatting added units
          @chart_reports.push(rpt)
          @charts.push(chart)
        end
      else                                    # Gen chart based on index
        chart = chart_layouts[@perf_options[:index].to_i]
        options = chart.merge({:zoom_url=>perf_zoom_url("perf_top_chart", "clear"),
                              :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
                              :width=>1000, :height=>700
                              })
        @chart_data.push(perf_gen_chart(rpt, options).merge({:menu=>chart[:menu]}))
        chart[:title] = rpt.title           # Grab title from chart in case formatting added units
        @chart_reports.push(rpt)
        @charts.push(chart)
      end
    when "tophour"
      chart_layouts = perf_get_chart_layout("hour_top_charts", cont_plus_model)
      unless @perf_options[:index]            # Gen all charts if no index present
        chart_layouts.each_with_index do |chart, idx|
          next if chart.nil?
          options = chart.merge({:zoom_url=>perf_zoom_url("perf_top_chart", idx.to_s),
                                :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )"
                                })
          rpt = rpts.pop                      # Get the next report object from the array
          @chart_data.push(perf_gen_chart(rpt, options).merge({:menu=>chart[:menu]}))
          chart[:title] = rpt.title           # Grab title from chart in case formatting added units
          @chart_reports.push(rpt)
          @charts.push(chart)
        end
      else                                    # Gen chart based on index
        chart = chart_layouts[@perf_options[:index].to_i]
        options = chart.merge({:zoom_url=>perf_zoom_url("perf_top_chart", "clear"),
                              :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
                              :width=>1000, :height=>700
                              })
        @chart_data.push(perf_gen_chart(rpt, options).merge({:menu=>chart[:menu]}))
        chart[:title] = rpt.title           # Grab title from chart in case formatting added units
        @chart_reports.push(rpt)
        @charts.push(chart)
      end
    end
    @sb[:chart_reports] = @chart_reports                    # Hang on to the reports for these charts
    @temp[:charts] = @charts
    @temp[:chart_data] = @chart_data
    @top_chart = true
    @html = perf_report_to_html(rpt)
  end

  # Generate daily utilization data for a model's charts
  def perf_util_daily_gen_data(refresh = nil)
    @perf_record ||= @record
    @sb[:util][:summary] = nil                            # Clear out existing summary report
    @sb[:util][:trend_charts] = nil                       # Clear out the charts to be generated

    # Get start/end dates in selected timezone
    s, e = @perf_record.first_and_last_capture
    return if s.nil?                                      # Nothing to do if no util data
    sdate = s.in_time_zone(@sb[:util][:options][:tz])
    edate = e.in_time_zone(@sb[:util][:options][:tz])
    # Eliminate partial start or end days
    sdate = sdate.hour == 00 ? sdate : sdate + 1.day
    edate = edate.hour < 23 ? edate - 1.day : edate
    return if sdate > edate                               # Don't have a full day's data

    charts = Array.new
    chart_data = Array.new
    chart_layouts = perf_get_chart_layout("daily_util_charts")
    if params[:miq_date_1] || params[:miq_date_2] # Only changed date for the timestamp charts, no need to rebuild the report object
      rpt = @sb[:util][:trend_rpt]
    else
      unless params[:task_id]                       # First time thru, generate report async
        rpt = perf_get_chart_rpt("vim_perf_util_daily")
        rpt.tz = @sb[:util][:options][:tz]
        rpt.time_profile_id = @sb[:util][:options][:time_profile]
        from = Date.parse(@sb[:util][:options][:chart_date]) - (@sb[:util][:options][:days].to_i - 1)
        mm, dd, yy = @sb[:util][:options][:chart_date].split("/")

        rpt.db_options = Hash.new
        rpt.db_options[:rpt_type] = "utilization"
        rpt.db_options[:interval] = "daily"
        rpt.db_options[:start_date] = @sb[:util][:options][:trend_start]        # Midnight on start day
        rpt.db_options[:end_date] = @sb[:util][:options][:trend_end]            # 11pm on end day
        rpt.db_options[:resource_type] = @perf_record.class.base_class.to_s
        rpt.db_options[:resource_id] = @perf_record.id
        rpt.db_options[:tag] = @sb[:util][:options][:tag]

        initiate_wait_for_task(:task_id => rpt.async_generate_table(
          :userid     => session[:userid],
          :session_id => request.session_options[:id],
          :mode       => "charts"))
        @waiting = true
        return
      end
    end

    if params[:task_id]                             # Came in after async report generation
      miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
      rpt = miq_task.miq_report_result.report_results # Grab the report object from the blob
      miq_task.destroy                              # Get rid of the task and results
    end
    unless @sb[:util][:options][:index]
      chart_layouts[@sb[:util][:options][:model].to_sym].each_with_index do |chart, idx|
        tag_class = @sb[:util][:options][:tag].split("/").first if @sb[:util][:options][:tag]
        if chart[:type] == "None" ||            # No chart is available for this slot
            (@sb[:util][:options][:tag] && chart[:allowed_child_tag] && !chart[:allowed_child_tag].include?(tag_class)) # Tag not allowed - Replace following line in sprint 69
#           (@sb[:util][:options][:tag] && chart[:allowed_child_tag] && !@sb[:util][:options][:tag].starts_with?(chart[:allowed_child_tag]))  # Tag not allowed
          chart_data.push(nil)              # Push a placeholder onto the chart data array
        else
          perf_remove_chart_cols(chart)
#           options = chart.merge({:zoom_url=>perf_zoom_url("capacity_chart_chooser", idx.to_s),
#                                 :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )"
#                                 })
#           options = chart.merge({:link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )"
#                                 })
          options = chart.merge({:axis_skip=>3})
          if chart[:trends]
            trendcol = perf_get_chart_trendcol(chart)
#             options[:trendtip] = chart[:trends].collect{|t| t.split(":").last + ": " +
#                                   rpt.extras[:trend][trendcol + "|" + t.split(":").first]}.join("\r") unless trendcol.nil?
          end
          options[:chart_type] = chart[:chart_type].to_sym if chart[:chart_type]  # Override :summary chart type if specified in chart definition
          options[:chart_date] = @sb[:util][:options][:chart_date]
          chart_data.push(perf_gen_chart(rpt, options).merge({:menu=>chart[:menu]}))
          chart[:title] = rpt.title           # Grab title from chart in case formatting added units
        end
        charts.push(chart)
      end
    else
      chart = chart_layouts[@sb[:util][:options][:model].to_sym][@sb[:util][:options][:index].to_i]
      perf_remove_chart_cols(chart)
#       options = chart.merge({:zoom_url=>perf_zoom_url("capacity_chart_chooser", "clear"),
#                             :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
#                             :width=>1000, :height=>700
#                             })
#       options = chart.merge({:link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
#                             :width=>1000, :height=>700
#                             })
      options = chart.merge({:axis_skip=>3})
      if chart[:trends]
        trendcol = perf_get_chart_trendcol(chart)
#         options[:trendtip] = chart[:trends].collect{|t| t.split(":").last + ": " +
#                               rpt.extras[:trend][trendcol + "|" + t.split(":").first]}.join("\r") unless trendcol.nil?
      end
      options[:chart_type] = chart[:chart_type].to_sym if chart[:chart_type]  # Override :summary chart type if specified in chart definition
      options[:chart_date] = @sb[:util][:options][:chart_date]
      chart_data.push(perf_gen_chart(rpt, options).merge({:menu=>chart[:menu]}))
      chart[:title] = rpt.title               # Grab title from chart in case formatting added units
      charts.push(chart)
    end
    @sb[:util][:trend_rpt] = rpt                  # Hang on to the report data for the trend charts
    @sb[:util][:trend_charts] = charts
    @sb[:util][:chart_data] = Hash.new
    @sb[:util][:chart_data]["utiltrend"] = chart_data

    # Generate the report and chart for the selected trend row (single day chart)
    ts_rpt = perf_get_chart_rpt("vim_perf_util_4_ts")
    tz = @sb[:util][:options][:time_profile_tz] || @sb[:util][:options][:tz]  # Use tz in time profile or chosen tz, if no profile tz
    ts_rpt.db_options = {:report=>rpt, :row_col=>"timestamp", :row_val=>create_time_in_tz(@sb[:util][:options][:chart_date] + " 00", tz)}
    ts_rpt.generate_table(:userid => session[:userid])
    @sb[:util][:ts_rpt] = ts_rpt                # Hang on to the timestamp report data
    ts_chart_layouts = perf_get_chart_layout("ts_util_charts")
    ts_chart = ts_chart_layouts[:MiqReport][0]  # For now, just use first chart
    @sb[:util][:ts_charts] = [ts_chart]         # Hang on to chart (as an array)
    ts_options = ts_chart
    ts_options[:chart_type] = ts_chart[:chart_type].to_sym if ts_chart[:chart_type] # Override chart type if specified in chart definition
    ts_chart_data = [perf_gen_chart(ts_rpt, ts_options)]
    @sb[:util][:chart_data]["utilts"] = ts_chart_data # Hang on to chart data

    @html = perf_report_to_html(rpt)            # Generate html version of the report
    @sb[:util][:summary] = perf_util_summary_info
  end

  # Generate performance vm planning data
  def perf_planning_gen_data(refresh = nil)
    @perf_record = MiqEnterprise.first

    unless params[:task_id] || params[:display_vms]     # First time thru, generate report async
      unless (refresh == "n" || params[:refresh] == "n") && @sb[:planning][:options] && @sb[:planning][:options][:model] == @perf_record.class.base_class.to_s
        @sb[:planning][:options] ||= Hash.new
        @sb[:planning][:options][:typ] = "Daily"
        @sb[:planning][:options][:days] ||= "30"
        @sb[:planning][:options][:model] = "VimPerformancePlanning"
        @sb[:planning][:options][:record_id] = @perf_record.id
      end
      @sb[:planning][:options][:trend_end] = perf_planning_end_date
      @sb[:planning][:options][:days] ||= "30"
      @sb[:planning][:options][:ght_type] ||= "hybrid"
      @sb[:planning][:options][:chart_type] = :summary
      @sb[:planning][:rpt] = nil                  # Clear existing planning report
      rpt = perf_get_chart_rpt("vim_perf_planning")

      rpt.headers[0] = "#{ui_lookup(:model=>@sb[:planning][:options][:target_typ])} Name"
      rpt.db_options = Hash.new
      rpt.db_options[:rpt_type] = "planning"
      # Set the default planning options
      rpt.db_options[:options] = {:vm_options => VimPerformancePlanning.vm_default_options(@sb[:planning][:options][:vm_mode])}

      if @sb[:planning][:options][:vm_mode] == :manual  # Set the manually entered values
        @sb[:planning][:options][:values].each do |k,v|
          if k.to_sym == :storage
            rpt.db_options[:options][:vm_options][k.to_sym][:value] = v * 1.gigabyte
          else
            rpt.db_options[:options][:vm_options][k.to_sym][:value] = v
          end
        end
      end

      rpt.db_options[:options][:vm] = @sb[:planning][:options][:chosen_vm] ? @sb[:planning][:options][:chosen_vm].to_i : nil

      rpt.db_options[:options][:range] = {
        :days=>@sb[:planning][:options][:days],
        :end_date=>@sb[:planning][:options][:trend_end]
        }

      rpt.db_options[:options][:target_tags] = {:compute_type => @sb[:planning][:options][:target_typ].to_sym}
      rpt.db_options[:options][:target_tags][:compute_filter] = @sb[:planning][:options][:target_filter] if @sb[:planning][:options][:target_filter]

      rpt.db_options[:options][:target_options] = Hash.new
      if @sb[:planning][:options][:trend_cpu]
        rpt.db_options[:options][:target_options][:cpu] = {
          :mode => :perf_trend,
          :metric => :max_cpu_usagemhz_rate_average,
          :limit_col => :derived_cpu_available,
          :limit_pct => @sb[:planning][:options][:limit_cpu]
          }
      end
      if @sb[:planning][:options][:trend_memory]
        rpt.db_options[:options][:target_options][:memory] = {
          :mode => :perf_trend,
          :metric => :max_derived_memory_used,
          :limit_col => :derived_memory_available,
          :limit_pct => @sb[:planning][:options][:limit_memory]
        }
      end
      if @sb[:planning][:options][:trend_storage]
        rpt.db_options[:options][:target_options][:storage] = {
          :mode       => :current,
          :metric     => :used_space,
          :limit_col  => :total_space,
          :limit_pct  => @sb[:planning][:options][:limit_storage]
        }
      end
      if @sb[:planning][:options][:trend_vcpus]
        rpt.db_options[:options][:target_options][:vcpus] = {
          :mode       => :current,
#         :metric     => :num_cpu, # Not applicable to vcpus
          :limit_col  => :total_vcpus, # not sure of name, but should be # vcpus/core times # of cores
          :limit_ratio => @sb[:planning][:options][:limit_vcpus]
        }
      end
      rpt.tz = @sb[:planning][:options][:tz]
      rpt.time_profile_id = @sb[:planning][:options][:time_profile]

      # Remove columns not checked in options
      [:cpu,:vcpus,:memory,:storage].each do |k|
        if @sb[:planning][:vm_opts][k].nil? || !@sb[:planning][:options]["trend_#{k.to_s}".to_sym]
          i = rpt.col_order.index("#{k.to_s}_vm_count")
          rpt.col_order.delete_at(i)
          rpt.headers.delete_at(i)
        end
      end

      initiate_wait_for_task(:task_id => rpt.async_generate_table(
        :userid     => session[:userid],
        :session_id => request.session_options[:id],
        :mode       => "charts"))
      return
    end

    charts = Array.new
    chart_data = Array.new
    chart_layouts = perf_get_chart_layout("planning_charts")

    # Remove columns not checked in options
    [:cpu,:vcpus,:memory,:storage].each do |k|
      if @sb[:planning][:vm_opts][k].nil? || !@sb[:planning][:options]["trend_#{k == :storage ? "disk" : k.to_s}".to_sym]
        chart_layouts[:VimPerformancePlanning].first[:columns].delete_if{|col| col == "#{k.to_s}_vm_count"}
      end
    end

    if params.has_key?(:display_vms)                # Only changed date for the timestamp charts, no need to rebuild the report object
      rpt = @sb[:planning][:rpt]
    elsif params[:task_id]                          # Came in after async report generation
      miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
      rpt = miq_task.miq_report_result.report_results # Grab the report object from the blob
      miq_task.destroy                              # Get rid of the task and results
    end
    @sb[:planning][:options][:index] = nil
    unless @sb[:planning][:options][:index]
      chart_layouts[@sb[:planning][:options][:model].to_sym].each_with_index do |chart, idx|
        if chart[:type] == "None" ||            # No chart is available for this slot
            (@sb[:planning][:options][:tag] && chart[:allowed_child_tag] && !@sb[:planning][:options][:tag].starts_with?(chart[:allowed_child_tag]))  # Tag not allowed
          chart_data.push(nil)              # Push a placeholder onto the chart data array
        else
#         perf_remove_chart_cols(chart)
#           options = chart.merge({:zoom_url=>perf_zoom_url("capacity_chart_chooser", idx.to_s),
#                                 :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )"
#                                 })
#           options = chart.merge({:link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )"
#                                 })
          options = chart
          if chart[:trends]
            trendcol = perf_get_chart_trendcol(chart)
          end
          options[:chart_type] = chart[:chart_type].to_sym if chart[:chart_type]  # Override :summary chart type if specified in chart definition
          options[:max_value] = @sb[:planning][:options][:display_vms] if @sb[:planning][:options][:display_vms]
          chart_data.push(perf_gen_chart(rpt, options).merge({:menu=>chart[:menu]}))
          chart[:title] = rpt.title           # Grab title from chart in case formatting added units
        end
        charts.push(chart)
      end
    else
      chart = chart_layouts[@sb[:planning][:options][:model].to_sym][@sb[:planning][:options][:index].to_i]
      perf_remove_chart_cols(chart)
#       options = chart.merge({:zoom_url=>perf_zoom_url("capacity_chart_chooser", "clear"),
#                             :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
#                             :width=>1000, :height=>700
#                             })
#       options = chart.merge({:link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
#                             :width=>1000, :height=>700
#                             })
      options = chart.merge({:width=>1000, :height=>700})
      if chart[:trends]
        trendcol = perf_get_chart_trendcol(chart)
      end
      options[:chart_type] = chart[:chart_type].to_sym if chart[:chart_type]  # Override :summary chart type if specified in chart definition
      options[:max_value] = @sb[:planning][:options][:display_vms] if @sb[:planning][:options][:display_vms]
      chart_data.push(perf_gen_chart(rpt, options).merge({:menu=>chart[:menu]}))
      chart[:title] = rpt.title                 # Grab title from chart in case formatting added units
      charts.push(chart)
    end
    @sb[:planning][:rpt] = rpt                  # Hang on to the report data for the trend charts
    @sb[:planning][:charts] = charts
    @sb[:planning][:chart_data] = Hash.new
    @sb[:planning][:chart_data]["planning"] = chart_data
  end

  # Get the ending trend date for planning trend lookups
  def perf_planning_end_date
    s, e = MiqEnterprise.first.first_and_last_capture
    return if s.nil?                                      # Nothing to do if no util data
    tz = @sb[:planning][:options][:time_profile_tz] || @sb[:planning][:options][:tz]  # Use tz in time profile or chosen tz, if no profile tz
    edate = e.in_time_zone(tz)
    edate = edate.hour < 23 ? edate - 1.day : edate # Eliminate partial end days
    return create_time_in_tz([edate.month, edate.day, edate.year].join("/") + " 23", tz)
  end

  # Generate a set of charts based on a report object
  def perf_gen_charts(rpt, perf_options)
    charts = Array.new
    chart_data = Array.new
    case perf_options[:typ]
    when "Hourly"
      chart_layout = perf_get_chart_layout("hourly_perf_charts", perf_options[:model])
      unless perf_options[:index]           # Gen all charts if no index present
        chart_layout.each_with_index do |chart, idx|
          if chart[:type] == "None"           # No chart is available for this slot
            chart_data.push(nil)              # Push a placeholder onto the chart data array
          else
            perf_remove_chart_cols(chart)
            options = chart.merge({:zoom_url=>perf_zoom_url("perf_chart_chooser", idx.to_s),
                                  :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
                                  :axis_skip=>3
                                  })
            menu_opts = perf_options[:model].starts_with?("Parent") ? {} : {:menu=>chart[:menu]}
            chart_data.push(perf_gen_chart(rpt, options).merge(menu_opts))
            chart[:title] = rpt.title           # Grab title from chart in case formatting added units
          end
          charts.push(chart)
        end
      else                                    # Gen chart based on index
        chart = chart_layout[perf_options[:index].to_i]
        perf_remove_chart_cols(chart)
        options = chart.merge({:zoom_url=>perf_zoom_url("perf_chart_chooser", "clear"),
                              :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
                              :axis_skip=>3,
                              :width=>1000, :height=>700
                              })
        menu_opts = perf_options[:model].starts_with?("Parent") ? {} : {:menu=>chart[:menu]}
        chart_data.push(perf_gen_chart(rpt, options).merge(menu_opts))
        chart[:title] = rpt.title           # Grab title from chart in case formatting added units
        charts.push(chart)
      end
    when "realtime"
      chart_layout = perf_get_chart_layout("realtime_perf_charts", perf_options[:model])
      unless perf_options[:index]           # Gen all charts if no index present
        chart_layout.each_with_index do |chart, idx|
          if chart[:type] == "None"           # No chart is available for this slot
            chart_data.push(nil)              # Push a placeholder onto the chart data array
          else
            perf_remove_chart_cols(chart)
            options = chart.merge({:zoom_url=>perf_zoom_url("perf_chart_chooser", idx.to_s),
                                  :axis_skip=>29})
            menu_opts = perf_options[:model].starts_with?("Parent") ? {} : {:menu=>chart[:menu]}
            chart_data.push(perf_gen_chart(rpt, options).merge(menu_opts))
            chart[:title] = rpt.title           # Grab title from chart in case formatting added units
          end
          charts.push(chart)
        end
      else                                    # Gen chart based on index
        chart = chart_layout[perf_options[:index].to_i]
        perf_remove_chart_cols(chart)
        options = chart.merge({:zoom_url=>perf_zoom_url("perf_chart_chooser", "clear"),
                              :axis_skip=>29,
                              :width=>1000, :height=>700
                              })
        menu_opts = perf_options[:model].starts_with?("Parent") ? {} : {:menu=>chart[:menu]}
        chart_data.push(perf_gen_chart(rpt, options).merge(menu_opts))
        chart[:title] = rpt.title           # Grab title from chart in case formatting added units
        charts.push(chart)
      end
    when "Daily"
      chart_layout = perf_get_chart_layout("daily_perf_charts", perf_options[:model])
      unless perf_options[:index]
        chart_layout.each_with_index do |chart, idx|
          if chart[:type] == "None"           # No chart is available for this slot
            chart_data.push(nil)              # Push a placeholder onto the chart data array
          else
            perf_remove_chart_cols(chart)
            options = chart.merge({:zoom_url=>perf_zoom_url("perf_chart_chooser", idx.to_s),
                                  :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
                                  :axis_skip=>3
                                  })
            if chart[:trends] && rpt.extras && rpt.extras[:trend]
              trendcol = perf_get_chart_trendcol(chart)
              options[:trendtip] = chart[:trends].collect{|t| t.split(":").last + ": " +
                                    rpt.extras[:trend][trendcol + "|" + t.split(":").first]}.join("\r") unless trendcol.nil?
            end
            menu_opts = perf_options[:model].starts_with?("Parent") ? {} : {:menu=>chart[:menu]}
            chart_data.push(perf_gen_chart(rpt, options).merge(menu_opts))
            chart[:title] = rpt.title           # Grab title from chart in case formatting added units
          end
          charts.push(chart)
        end
      else
        chart = chart_layout[perf_options[:index].to_i]
        if chart
          perf_remove_chart_cols(chart)
          options = chart.merge({:zoom_url=>perf_zoom_url("perf_chart_chooser", "clear"),
                                :link_data_url=>"javascript:miqChartLinkData( _col_, _row_, _value_, _category_, _series_, _id_ )",
                                :axis_skip=>3,
                                :width=>1000, :height=>700
                                })
          if chart[:trends] && rpt.extras && rpt.extras[:trend]
            trendcol = perf_get_chart_trendcol(chart)
            options[:trendtip] = chart[:trends].collect{|t| t.split(":").last + ": " +
                                  rpt.extras[:trend][trendcol + "|" + t.split(":").first]}.join("\r") unless trendcol.nil?
          end
          menu_opts = perf_options[:model].starts_with?("Parent") ? {} : {:menu=>chart[:menu]}
          chart_data.push(perf_gen_chart(rpt, options).merge(menu_opts))
          chart[:title] = rpt.title           # Grab title from chart in case formatting added units
          charts.push(chart)
        end
      end
    end
    return charts, chart_data
  end

  # Generate performance chart data for a report based on passed in options
  def perf_gen_chart(report, options)
    options[:chart_type] ||= @perf_options[:chart_type]     # Set chart_type for the set of charts, unless overridden already for this chart
    options[:width]  ||= 350
    options[:height] ||= 250
    report.title = options[:title]
    report.graph ||= {}
    report.graph[:type]    = options[:type]
    report.graph[:columns] = options[:columns]
    report.graph[:legends] = options[:legends]
    report.graph[:max_col_size] = options[:max_value]
    # FIXME: rename xml, xml2 to something like 'chart_data'
    report.to_chart(@settings[:display][:reporttheme], true,
                  MiqReport.graph_options(options[:width], options[:height], options))

    chart_xml = {
      :xml      => report.chart,            # Save the graph xml
      :main_col => options[:columns].first  # And the main (first) column of the chart
    }
    if options[:chart2]
      report.graph[:type]    = options[:chart2][:type]
      report.graph[:columns] = options[:chart2][:columns]
      report.to_chart(@settings[:display][:reporttheme], true,
                    MiqReport.graph_options(options[:width], options[:height], options.merge({:composite=>true})))
      chart_xml[:xml2] = report.chart
    end
    chart_xml
  end

  # Build the category pulldown for tag charts
  def perf_build_cats(model)
    cats = Classification.categories.collect {|c| c unless !c.show}.compact.sort{|a,b| a.description <=> b.description} # Get the categories, sort by name
    cats.delete_if{ |c| c.read_only? || c.entries.length == 0}                    # Remove categories that are read only or have no entries
    ret_cats = {"<None>"=>"<None>"}                                               # Classifications hash for chooser
    case model
    when "Host", "Storage", "AvailabilityZone"
      cats.each {|c| ret_cats["Vm:" + c.name] = "VM " + c.description}            # Add VM categories to the hash
    when "EmsCluster"
      cats.each {|c| ret_cats["Host:" + c.name] = "Host " + c.description}        # Add VM categories to the hash
      cats.each {|c| ret_cats["Vm:" + c.name] = "VM " + c.description}            # Add VM categories to the hash
    end
    return ret_cats
  end

  # Build the chart zoom url
  def perf_zoom_url(action, idx)
    url = "javascript:miqAsyncAjax('" +
          url_for(:only_path => true,
                  :action    => action,
                  :id        => @perf_record.id,
                  :chart_idx => idx) +
                  "')"
    url.gsub!(/'/,'\\\\\&')             # Escape single quotes for ZiYa XML rendering
  end

  # Generate the html view of the chart report
  def perf_report_to_html(rpt=nil, charts = nil)
    rpt ||= @sb[:chart_reports]               # Set default if not passed in
    title = rpt.title
    rpt.title = @title.gsub(/Capacity & Utilization/,"#{@perf_options[:typ]} C & U") + " - #{title}"
    return if @perf_options[:ght_type] == "graph" || @perf_options[:index] == nil # Don't show html for graph setting or if multiple charts are showing
    report = rpt.class == Array ? rpt.first : rpt # Get the first or only report
    report = perf_remove_report_cols(report, charts)  # Remove cols that are not in the current chart
    return report.to_html                     # Create html from the chart report
  end

  # Generate @summary_info array from report and chart data
  def perf_util_summary_info
    si = Hash.new
    si[:info] = Array.new
    si[:info].push(["Utilization Trend Summary for", @sb[:util][:options][:model] == "MiqEnterprise" ? "Enterprise" : "#{ui_lookup(:model=>@sb[:util][:options][:model])} [#{@perf_record.name}]"])
    si[:info].push(["Trend Interval", "#{format_timezone(@sb[:util][:options][:trend_start],@sb[:util][:options][:tz],"date")} - #{format_timezone(@sb[:util][:options][:trend_end],@sb[:util][:options][:tz],"date")}"])
    si[:info].push(["Selected Day", format_timezone(@sb[:util][:options][:chart_date].to_time,"UTC","date")])
    si[:info].push(["Time Profile", session[:time_profiles][@sb[:util][:options][:time_profile]]]) if @sb[:util][:options][:time_profile]
    si[:info].push(["Time Zone", @sb[:util][:options][:time_profile_tz] ? @sb[:util][:options][:time_profile_tz] : @sb[:util][:options][:tz]])
    si[:info].push(["Classification", @sb[:util][:tags][@sb[:util][:options][:tag]]]) if @sb[:util][:options][:tag]

    if @sb[:util][:trend_charts]
      si[:cpu] = perf_util_summary_section("cpu")         # Get the cpu section
      si[:memory] = perf_util_summary_section("memory")   # Get the memory section
      si[:storage] = perf_util_summary_section("disk")    # Get the disk section
    end

    return si
  end

  # Build a section of the summary info hash
  def perf_util_summary_section(s)  # Pass in section name and selected table row
    ss = Array.new

    # Fill in the single day data from the timestamp report
    ts_rpt = @sb[:util][:ts_rpt]
    total_vals = 0.0
    ts_rpt.table.data.each do |r|
      next unless r[0].downcase.include?(s)
      ts_rpt.col_order.each_with_index do |col, col_idx|
        next unless col.ends_with?("_percent")

        # Do NOT show reserve (available) column for Host and Storage nodes
        next if col.include?("_reserve") && ["Host","Storage"].include?(@sb[:util][:options][:model])

        case s  # Override the formatting for certain column groups on single day percent utilization chart
        when "cpu"
          tip = ts_rpt.format(col + '_tip', r[col + '_tip'],
                          :format => {:function=>
                            {
                            :name=>"mhz_to_human_size",
                            :precision=>1
                            }
                          })
        when "memory"
          tip = ts_rpt.format(col + '_tip', r[col + '_tip'].to_f*1024*1024,
                          :format => {:function=>
                            {
                            :name=>"bytes_to_human_size",
                            :precision=>1
                            }
                          })
        when "disk"
          tip = ts_rpt.format(col + '_tip', r[col + '_tip'],
                          :format => {:function=>
                            {
                            :name=>"bytes_to_human_size",
                            :precision=>1
                            }
                          })
        else
          tip = ts_rpt.format(col + '_tip', r[col + '_tip'])
        end
        val = ts_rpt.format(col, r[col], :format => {:function=>{:name=>"number_with_delimiter", :suffix=>"%"}, :precision=>"0"})
        ss.push([ts_rpt.headers[col_idx], "#{tip} (#{val})"])
        total_vals += r[col].to_f # Total up the values for this section
      end
    end
    return nil if total_vals == 0 # If no values, return nil so this section won't show on the screen

    # Get the trend information from the trend charts/report
    @sb[:util][:trend_charts].each do |c|
      s = "storage" if s == "disk"  # disk fields have 'storage' in them
      next unless c[:columns].first.include?("#{s}_")
      if c[:trends]
        c[:trends].each do |t|
          c[:columns].each do |trendcol|
            next if !trendcol.starts_with?("trend_")
            ss.push([Dictionary::gettext(trendcol, :type=>:column, :notfound=>:titleize) + ": " + t.split(":").last,
                    @sb[:util][:trend_rpt].extras[:trend][trendcol + "|" + t.split(":").first]]) unless trendcol.nil?
          end
        end
      end
    end
    return ss
  end

  # Remove cols from report object cols and col_order that are not in a chart before the report is run
  def perf_trim_report_cols(report, chart)
    keepcols = Array.new
    keepcols += ["timestamp", "resource_name", "assoc_ids"]
    keepcols += chart[:columns]
    keepcols += chart[:chart2][:columns] if chart[:chart2]
    # First remove columns from the col_order and header arrays
    report.cols.delete_if{|c| !keepcols.include?(c)}    # Remove columns
    cols = report.col_order.length                      # Remove col_order and header elements
    (1..cols).each do |c|
      idx = cols - c                    # Go thru arrays in reverse
      unless keepcols.include?(report.col_order[idx])
        report.col_order.delete_at(idx)
        report.headers.delete_at(idx)
      end
    end
  end

  # Remove cols from report object that are not in the current chart after the report is run
  def perf_remove_report_cols(report, charts = nil)
    charts ||= @temp[:charts].first
    new_rpt = MiqReport.new(report.attributes)  # Make a copy of the report
    new_rpt.table = Marshal.load(Marshal.dump(report.table))
    keepcols = Array.new
    keepcols += ["timestamp", "statistic_time"] unless @top_chart
#   keepcols += ["resource_name"] if @temp[:charts].first[:type].include?("Pie")
#   keepcols += @temp[:charts].first[:columns]
#   keepcols += @temp[:charts].first[:chart2][:columns] if @temp[:charts].first[:chart2]
    keepcols += ["resource_name"] if charts[:type].include?("Pie")
    keepcols += charts[:columns]
    keepcols += charts[:chart2][:columns] if charts[:chart2]
    # First remove columns from the col_order and header arrays
    cols = new_rpt.col_order.length
    (1..cols).each do |c|
      idx = cols - c                    # Go thru arrays in reverse
      unless keepcols.include?(new_rpt.col_order[idx])
        new_rpt.col_order.delete_at(idx)
        new_rpt.headers.delete_at(idx)
      end
    end
    # Now remove columns from the cols array so we don't include them in the CSV download
    new_rpt.cols.each do |c|
      unless keepcols.include?(c)
        new_rpt.table.remove_column(c)
      end
    end
    return new_rpt
  end

end
