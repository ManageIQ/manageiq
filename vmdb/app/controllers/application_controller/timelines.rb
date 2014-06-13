module ApplicationController::Timelines
  extend ActiveSupport::Concern

  # Process changes to timeline selection
  def tl_chooser
    @record = identify_tl_or_perf_record
    @tl_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record
    @tl_options[:typ] = params[:tl_typ] if params[:tl_typ]
    @tl_options[:days] = params[:tl_days] if params[:tl_days]
    @tl_options[:hourly_date] = params[:miq_date_1] if params[:miq_date_1] && @tl_options[:typ] == "Hourly"
    @tl_options[:daily_date] = params[:miq_date_1] if params[:miq_date_1] && @tl_options[:typ] == "Daily"

    # set variables for type of timeline is selected
    if params[:tl_show]
      @tl_options[:tl_show] = params[:tl_show]
      tl_gen_timeline_data
      return unless @temp[:timeline]
    end

    if @tl_options[:tl_show] == "timeline"
      @tl_options[:filter1] = params[:tl_fl_grp1] if params[:tl_fl_grp1]
      @tl_options[:filter2] = params[:tl_fl_grp2] if params[:tl_fl_grp2]
      @tl_options[:filter3] = params[:tl_fl_grp3] if params[:tl_fl_grp3]
      #if pull down values have been switched
      @tl_options[:filter1] = "" if (@tl_options[:filter1] == @tl_options[:filter2] || @tl_options[:filter1] == @tl_options[:filter3]) && !params[:tl_fl_grp1]
      @tl_options[:filter2] = "" if (@tl_options[:filter2] == @tl_options[:filter3] || @tl_options[:filter2] == @tl_options[:filter1]) && !params[:tl_fl_grp2]
      @tl_options[:filter3] = "" if (@tl_options[:filter3] == @tl_options[:filter2] || @tl_options[:filter3] == @tl_options[:filter1]) && !params[:tl_fl_grp3]
    else
      @tl_options[:tl_result] = params[:tl_result] if params[:tl_result]
      if params[:tl_fl_grp_all] == "1"
        @tl_options[:tl_filter_all] = true
        @tl_options[:etypes].sort.each do |e|
          @tl_options[:applied_filters].push(e)
        end
      elsif params[:tl_fl_grp_all] == "null"
        @tl_options[:tl_filter_all] = false
        @tl_options[:applied_filters] = Array.new
        @tl_options[:events].sort.each_with_index do |e,i|
          @tl_options["pol_filter#{i+1}".to_sym] = ""
          @tl_options["pol_fltr#{i+1}".to_sym] = ""
        end
      end
      # Look through the event type checkbox keys
      @tl_options[:etypes].sort.each_with_index do |e,i|
        ekey = "tl_fl_grp#{i+1}__#{e.gsub(" ", "_")}".to_sym
        if params[ekey] == "1" || (@tl_options[:tl_filter_all] && params[ekey] != "null")
          @tl_options["pol_filter#{i+1}".to_sym] = e
          @tl_options[:applied_filters].push(e) unless @tl_options[:applied_filters].include?(e) || @tl_options[:tl_filter_all] = false
        elsif params[ekey] == "null"
          @tl_options[:tl_filter_all] = false
          @tl_options["pol_filter#{i+1}".to_sym] = nil
          @tl_options[:applied_filters].delete(e)
        end
      end
    end

    @tl_options[:fl_typ] = params[:tl_fl_typ] if params[:tl_fl_typ]
    if @tl_options[:tl_show] == "timeline" &&
        (@tl_options[:filter1].nil? || @tl_options[:filter1] == "") &&
        (@tl_options[:filter2].nil? || @tl_options[:filter2] == "") &&
        (@tl_options[:filter3].nil? || @tl_options[:filter3] == "")
      add_flash(I18n.t("flash.edit.at_least_1.selected", :field=>"filter"), :warning)
    elsif @tl_options[:tl_show] == "policy_timeline"
      flg = true
      @tl_options[:events].sort.each_with_index do |e,i|
        if !@tl_options["pol_filter#{i+1}".to_sym].nil? && @tl_options["pol_filter#{i+1}".to_sym] != ""
          flg = false
          tl_build_timeline(refresh="n")
          break
        end
      end
      add_flash(I18n.t("flash.edit.at_least_1.selected", :field=>"filter"), :warning) if flg
    else
      tl_gen_timeline_data(refresh="n")
      return unless @temp[:timeline]
    end

    if @tl_options[:tl_show] == "timeline"
      if !@tl_options[:filter1].nil? && @tl_options[:filter1] != ""
        @tl_options[:fltr1] = tl_build_filter(@tl_groups_hash[@tl_options[:filter1]])
      else
        @tl_options[:fltr1] = ""
      end
      if !@tl_options[:filter2].nil? && @tl_options[:filter2] != ""
        @tl_options[:fltr2] = tl_build_filter(@tl_groups_hash[@tl_options[:filter2]])
      else
        @tl_options[:fltr2] = ""
      end
      if !@tl_options[:filter3].nil? && @tl_options[:filter3] != ""
        @tl_options[:fltr3] = tl_build_filter(@tl_groups_hash[@tl_options[:filter3]])
      else
        @tl_options[:fltr3] = ""
      end
    else
      @tl_options[:events].sort.each_with_index do |e,i|
        fltr = "pol_filter#{i+1}".to_sym
        pol_fltr = "pol_fltr#{i+1}".to_sym
        if !@tl_options[fltr].nil? && @tl_options[fltr] != ""
          f = tl_build_policy_filter(@tl_options[fltr])
          @tl_options[pol_fltr] = f == "" ? "" : f
        else
          @tl_options[pol_fltr] = ""
        end
      end
    end
    @temp[:timeline] = true
    add_flash(I18n.t("flash.no_timeline_events_found"), :warning) if @tl_options[:sdate].nil? && @tl_options[:edate].nil?
    render :update do |page|
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      page.replace("tl_options_div", :partial=>"layouts/tl_options")
      page.replace("tl_div", :partial=>"layouts/tl_detail")
      page << "miq_cal_dateFrom = new Date(#{@tl_options[:sdate]});" unless @tl_options[:sdate].nil?
      page << "miq_cal_dateTo = new Date(#{@tl_options[:edate]});" unless @tl_options[:edate].nil?
      page << 'miqBuildCalendar();'
      if @tl_options[:tl_show] == "timeline"
        page << "$('filter1').value='#{@tl_options[:fltr1]}';"
        page << "$('filter2').value='#{@tl_options[:fltr2]}';"
        page << "$('filter3').value='#{@tl_options[:fltr3]}';"
      else
        @tl_options[:events].sort.each_with_index do |e,i|
          fltr = "pol_fltr#{i+1}".to_sym
          page << "$('filter#{i+1}').value='#{@tl_options[fltr]}';"
        end
      end
      page << "miqSparkle(false);"
      #page << 'performFiltering(tl, [0,1]);'
    end
  end

  def getTLdata
    if session[:tl_xml_blob_id] != nil
      blob = BinaryBlob.find(session[:tl_xml_blob_id])
      render :xml=>blob.binary
      blob.destroy
      session[:tl_xml_blob_id] = session[:tl_position] = nil #if params[:controller] != "miq_capacity"
    else
      require 'miq-xml'
      tl_xml = MiqXml.load("<data/>")
      #   tl_event = tl_xml.root.add_element("event", {
      #                                                   "start"=>"May 16 2007 08:17:23 GMT",
      #                                                   "title"=>"Dans-XP-VM",
      #                                                   "image"=>"images/icons/20/20-VMware.png",
      #                                                   "text"=>"VM &lt;a href=\"/vm/guest_applications/3\"&gt;Dan-XP-VM&lt;/a&gt; cloned to &lt;a href=\"/vm/guest_applications/1\"&gt;WinXP Testcase&lt;/a&gt;."
      #                                                   })
      Vm.all.each do | vm |
        event = tl_xml.root.add_element("event", {
#           START of TIMELINE TIMEZONE Code
#           "start"=>format_timezone(vm.created_on,Time.zone,"tl"),
            "start"=>vm.created_on,
#           END of TIMELINE TIMEZONE Code
            #                                       "end" => Time.now,
            #                                       "isDuration" => "true",
            "title"=>vm.name.length < 25 ? vm.name : vm.name[0..22] + "...",
            #                                       "title"=>vm.name,
            #"image"=>"/images/icons/20/20-#{vm.vendor.downcase}.png"
            "icon"=>"/images/icons/new/vendor-#{vm.vendor.downcase}.png",
            "color"=>"blue",
            #"image"=>"/images/icons/64/64-vendor-#{vm.vendor.downcase}.png"
            "image"=>"/images/icons/new/os-#{vm.os_image_name.downcase}.png"
            #                                       "text"=>"VM &lt;a href='/vm/guest_applications/#{vm.id}'&gt;#{h(vm.name)}&lt;/a&gt; discovered at location #{h(vm.location)}&gt;."
          })
        #     event.text = "VM #{vm.name} discovered on #{vm.created_on}"
        event.text = "VM &lt;a href='/vm/guest_applications/#{vm.id}'&gt;#{vm.name}&lt;/a&gt; discovered at location #{vm.location}"
      end
      render :xml=>tl_xml.to_s
    end
  end

  private ############################

    # Gather information for the report/timeline menu trees accordians
  def build_timeline_tree(rpt_menu,tree_type)
    @rep_tree = Hash.new
    @group_idx = Array.new
    @report_groups = Array.new
    @branch = Array.new
    @tree_type = tree_type
    rpt_menu.each do |r|
      @group_idx.push(r[0]) unless @group_idx.include?(r[0])
      @report_groups.push(r[0]) unless @report_groups.include?(r[0])
      r.each_slice(2) do |menu,section|
        section.each_with_index do |s,j|
          if s.class == Array
            s.each do |rec|
              @branch_node = Array.new
              if rec.class == String
                @parent_node = Hash.new
                @parent_node = TreeNodeBuilder.generic_tree_node(
                    "p__#{rec}",
                    rec,
                    "folder.png",
                    "Group: #{rec}",
                    :style_class   => "cfme-no-cursor-node",
                )
              else
                rec.each_with_index do |r,i|
                  if i%2 == 0
                    nodecolor = "#dddddd"
                  else
                    nodecolor = ""
                  end
                  temp = timeline_kids_tree(r,nodecolor)
                  @branch_node.push(temp) unless temp.nil? || temp.empty?
                end
                @parent_node[:children] = @branch_node unless @branch_node.nil? || @parent_node.include?(@branch_node)
              end
              @branch.push(@parent_node) unless @parent_node.nil? || @branch.include?(@parent_node)
            end
          elsif s.class == String
            if j%2 == 0
              nodecolor = "#dddddd"
            else
              nodecolor = ""
            end
            temp = timeline_kids_tree(s,nodecolor)
            @branch.push(temp) unless temp.nil? || temp.empty?
          end
        end
        @rep_tree[menu] = @branch.to_json unless @branch.nil? || @branch.empty?
        @branch = Array.new
      end
    end
  end

  def timeline_kids_tree(rec,node_color)
    rpt = MiqReport.find_by_name(rec)
    @tag_node = Hash.new
    if !rpt.nil?
      @tag_node = TreeNodeBuilder.generic_tree_node(
          "#{rpt.id}__#{rpt.name}",
          rpt.name,
          "link_internal.gif",
          "Report: #{rpt.name}",
          :style_class => "cfme-no-cursor-node",
          :style       => "background-color:#{node_color};padding-left: 0px;"     # No cursor pointer
      )
    end
    return @tag_node
  end

  def build_timeline(timeline_typ="Operation")
    @tl_options[:typ] = timeline_typ
    if timeline_typ == "Configuration"
      timeline_name = "Configurations All Events"
    else
      timeline_name = "Operations All Events"
    end
    @report = MiqReport.find_by_name(timeline_name)
    @report.where_clause = @record.event_where_clause
    @title = @report.title

    begin
      @report.generate_table(:userid => session[:userid])
    rescue StandardError => bang
      add_flash(I18n.t("flash.error_building_timeline") << bang.message, :error)
    else
      if @report.table.data.length == 0
        add_flash(I18n.t("flash.no_timeline_records_found"), :warning)
      else
        @timeline = true
        @report.extras[:browser_name] = browser_info("name").downcase
        if is_browser_ie?
          blob = BinaryBlob.new(:name => "timeline_results")
          blob.binary=(@report.to_timeline)
          session[:tl_xml_blob_id] = blob.id
        else
          @temp[:tl_json] = @report.to_timeline
        end
#       START of TIMELINE TIMEZONE Code
#       session[:tl_position] = format_timezone(@report.extras[:tl_position],Time.zone,"tl")
        session[:tl_position] = @report.extras[:tl_position]
#       END of TIMELINE TIMEZONE Code
      end
    end
  end

  def tl_get_rpt(timeline)
    return MiqReport.new(YAML::load(File.open("#{TIMELINES_FOLDER}/miq_reports/#{timeline.to_s}.yaml")))
  end

  def tl_build_filter(grp_name)             # hidden fields to highlight bands in timeline
    arr = TL_ETYPE_GROUPS[grp_name][@tl_options[:fl_typ].downcase.to_sym]
    arr.push(TL_ETYPE_GROUPS[grp_name][:critical]) if @tl_options[:fl_typ].downcase == "detail"
    filter = "(" << arr.join(")|(") << ")"
    return filter
  end

  def tl_build_policy_filter(grp_name)      # hidden fields to highlight bands in timeline
    arr = Array.new
    @tl_options[:events][grp_name].each do |a|
      e = PolicyEvent.find_by_miq_event_id(a.to_i)
      if !e.nil?
        arr.push(e.event_type)
      end
    end
    if !arr.blank?
      filter = "(" << arr.join(")|(") << ")"
    else
      filter = ""
    end
    return filter
  end

  def tl_build_init_options(refresh = nil)
    @tl_record = @record.kind_of?(MiqServer) ? @record.vm : @record # Use related server vm record
    unless @tl_options &&
        ((refresh == "n" || params[:refresh] == "n") ||
            (@tl_options && @tl_options[:model] == @tl_record.class.base_class.to_s))
      @tl_options = Hash.new
      @tl_options[:typ] = "Daily"
      @tl_options[:days] = "7"
      @tl_options[:model] = @tl_record.class.base_class.to_s
      @tl_options[:tl_show_options] = Array.new
      @tl_options[:tl_show_options].push(["Management Events","timeline"])
      @tl_options[:tl_show_options].push(["Policy Events","policy_timeline"])
      @tl_options[:tl_show] = "timeline"
    end
    evt_type = @tl_options[:tl_show] == "timeline" ? "ems_events" : "policy_events"
    sdate, edate = @tl_record.first_and_last_event(evt_type.to_sym)
    if !sdate.nil? && !edate.nil?
      @tl_options[:sdate] = [sdate.year.to_s, (sdate.month - 1).to_s, sdate.day.to_s].join(", ")
      @tl_options[:edate] = [edate.year.to_s, (edate.month - 1).to_s, edate.day.to_s].join(", ")
      @tl_options[:hourly_date] ||= [edate.month, edate.day, edate.year].join("/")
      @tl_options[:daily_date] ||= [edate.month, edate.day, edate.year].join("/")
    else
      @tl_options[:sdate] = @tl_options[:edate] = nil
    end
    @tl_options[:days] ||= "7"

    if @tl_options[:tl_show] == "policy_timeline"
      @tl_options[:all_results] = Hash.new
      @tl_options[:all_results]["Both"] = "both"
      @tl_options[:all_results]["True"] = "success"
      @tl_options[:all_results]["False"] = "failure"
      @tl_options[:tl_result] ||= "both"

      @tl_options[:events] = Hash.new
      @tl_options[:etypes] = Array.new
      MiqEventSet.all.each do |e|
        @tl_options[:etypes].push(e.description)  unless @tl_options[:etypes].include?(e.description)
        @tl_options[:events][e.description] ||= Array.new
        e.members.each do |mem|
          @tl_options[:events][e.description].push(mem.id) unless @tl_options[:events][e.description].include?(mem.id)
        end
      end
      @tl_options[:applied_filters] ||= Array.new
      if @tl_options[:applied_filters].blank?
        @tl_options[:applied_filters].push("VM Operation")
        # had to set this here because if it this is preselected in cboxes, it doesnt send the params back for this cb to tl_chooser
        @tl_options[:etypes].sort.each_with_index do |e,i|
          if e == "VM Operation"
            @tl_options["pol_filter#{i+1}".to_sym] = e
            @tl_options["pol_fltr#{i+1}".to_sym] = tl_build_policy_filter(@tl_options["pol_filter#{i+1}".to_sym])
          end
        end
      end
    else
      @tl_options[:groups] = Array.new
      @tl_groups_hash = Hash.new
      TL_ETYPE_GROUPS.each do |gname,list|
        if gname != :vdi || (gname == :vdi && get_vmdb_config[:product][:vdi])
          @tl_options[:groups].push(list[:name].to_s)
          @tl_groups_hash[list[:name].to_s] = gname
        end
      end
      @tl_options[:fl_typ] = "critical" if @tl_options[:fl_typ].nil?
      if @tl_options[:filter1].nil?
        @tl_options[:filter1] = "Power Activity"
        @tl_options[:fltr1] = tl_build_filter(@tl_groups_hash[@tl_options[:filter1]])
      end
    end

    @tl_options[:tl_colors] = ["#CD051C", "#005C25", "#035CB1", "#FF3106", "#FF00FF", "#000000"]
  end

  def tl_build_timeline_report_options
    evt_type = @tl_options[:tl_show] == "timeline" ? "ems_events" : "policy_events"
    sdate, edate = @tl_record.first_and_last_event(evt_type.to_sym)
    if !@tl_options[:sdate].nil? && !@tl_options[:edate].nil?
      case @tl_options[:typ]
        when "Hourly"
          tl_rpt = @tl_options[:tl_show] == "timeline" ? "tl_events_hourly" : "tl_policy_events_hourly"
          @report = tl_get_rpt(tl_rpt)
          mm, dd, yy = @tl_options[:hourly_date].split("/")
          from_dt = create_time_in_utc("#{yy}-#{mm}-#{dd} 00:00:00", session[:user_tz]) # Get tz 12am in user's time zone
          to_dt = create_time_in_utc("#{yy}-#{mm}-#{dd} 23:59:59", session[:user_tz])   # Get tz 11pm in user's time zone
          st_time = Time.gm(yy,mm,dd,00,00,00)
          end_time = Time.gm(yy,mm,dd,23,59,00)
                                                                                         #        START of TIMELINE TIMEZONE Code
                                                                                         #        @report.timeline[:bands][0][:center_position] = Time.gm(yy,mm,dd,21,00,00)    # calculating mid position to align timeline in center
                                                                                         #        @report.timeline[:bands][0][:st_time] = st_time.strftime("%b %d %Y 00:00:00 GMT")
                                                                                         #        @report.timeline[:bands][0][:end_time] = end_time.strftime("%b %d %Y 23:59:00 GMT")
          tz = @report.tz ? @report.tz : Time.zone
          @report.timeline[:bands][0][:center_position] = format_timezone(Time.gm(yy,mm,dd,21,00,00),tz,"tl")
          @report.timeline[:bands][0][:st_time] = format_timezone(st_time,tz,"tl")
          @report.timeline[:bands][0][:end_time] = format_timezone(end_time,tz,"tl")
                                                                                         #        END of TIMELINE TIMEZONE Code
          @report.timeline[:bands][0][:pixels] = 1000/6
          @report.timeline[:bands][0][:decorate] = true
          @report.timeline[:bands][0][:hourly] = true
        when "Daily"
          tl_rpt = @tl_options[:tl_show] == "timeline" ? "tl_events_daily" : "tl_policy_events_daily"
          @report = tl_get_rpt(tl_rpt)
          from = Date.parse(@tl_options[:daily_date]) - @tl_options[:days].to_i
          from_dt = create_time_in_utc("#{from.year}-#{from.month}-#{from.day} 00:00:00", session[:user_tz])  # Get tz 12am in user's time zone
          mm, dd, yy = @tl_options[:daily_date].split("/")
          to_dt = create_time_in_utc("#{yy}-#{mm}-#{dd} 23:59:59", session[:user_tz]) # Get tz 11pm in user's time zone
          @report.timeline[:bands][0][:decorate] = true
          st_time = Time.gm(from.year,from.month,from.day,00,00,00)
          end_time = Time.gm(yy,mm,dd,23,59,00)
          mid = Date.parse(to_dt.to_s) - 2      # calculating mid position to align timeline in center
                                                                                                              #       START of TIMELINE TIMEZONE Code
                                                                                                              #       @report.timeline[:bands][0][:center_position] = Time.gm(mid.year,mid.month,mid.day,12,00,00)
                                                                                                              #       @report.timeline[:bands][0][:st_time] = st_time.strftime("%b %d %Y 00:00:00 GMT")
                                                                                                              #       @report.timeline[:bands][0][:end_time] = end_time.strftime("%b %d %Y 23:59:00 GMT")
          tz = @report.tz ? @report.tz : Time.zone
          @report.timeline[:bands][0][:center_position] = format_timezone(Time.gm(mid.year,mid.month,mid.day,12,00,00),tz,"tl")
          @report.timeline[:bands][0][:st_time] = format_timezone(st_time,tz,"tl")
          @report.timeline[:bands][0][:end_time] = format_timezone(end_time,tz,"tl")
                                                                                                              #       END of TIMELINE TIMEZONE Code
          @report.timeline[:bands][0][:pixels] = 1000/6
      end

      temp_clause = @tl_record.event_where_clause(evt_type.to_sym)

      cond = "( "
      cond = cond << temp_clause[0]
      params = Array.new
      params2 = Array.new
      params = temp_clause.slice(1, temp_clause.length)

      event_set = Array.new

      if @tl_options[:tl_show] == "policy_timeline"
        if !@tl_options[:applied_filters].blank?
          @tl_options[:applied_filters].each do |e|
            event_set.push(@tl_options[:events][e])
          end
        end
      else
        if (!@tl_options[:filter1].nil? && @tl_options[:filter1] != "") ||
            (!@tl_options[:filter2].nil? && @tl_options[:filter2] != "") ||
            (!@tl_options[:filter3].nil? && @tl_options[:filter3] != "")
          if !@tl_options[:filter1].nil? && @tl_options[:filter1] != ""
            event_set.push(TL_ETYPE_GROUPS[@tl_groups_hash[@tl_options[:filter1]]][@tl_options[:fl_typ].downcase.to_sym]) if @tl_groups_hash[@tl_options[:filter1]]
            event_set.push(TL_ETYPE_GROUPS[@tl_groups_hash[@tl_options[:filter1]]][:detail]) if @tl_options[:fl_typ].downcase == "detail"
          end
          if !@tl_options[:filter2].nil? && @tl_options[:filter2] != ""
            event_set.push(TL_ETYPE_GROUPS[@tl_groups_hash[@tl_options[:filter2]]][@tl_options[:fl_typ].downcase.to_sym]) if @tl_groups_hash[@tl_options[:filter2]]
            event_set.push(TL_ETYPE_GROUPS[@tl_groups_hash[@tl_options[:filter2]]][:detail]) if @tl_options[:fl_typ].downcase == "detail"
          end
          if !@tl_options[:filter3].nil? && @tl_options[:filter3] != ""
            event_set.push(TL_ETYPE_GROUPS[@tl_groups_hash[@tl_options[:filter3]]][@tl_options[:fl_typ].downcase.to_sym]) if @tl_groups_hash[@tl_options[:filter3]]
            event_set.push(TL_ETYPE_GROUPS[@tl_groups_hash[@tl_options[:filter3]]][:detail]) if @tl_options[:fl_typ].downcase == "detail"
          end
        else
          event_set.push(TL_ETYPE_GROUPS[:power][@tl_options[:fl_typ].to_sym])
        end
      end

      if !event_set.empty?
        if @tl_options[:tl_show] == "policy_timeline" && @tl_options[:tl_result] != "both"
          ftype = @tl_options[:tl_show] == "timeline" ? "event_type" : "miq_event_id"
          where_clause = [") and (timestamp >= ? and timestamp <= ?) and (#{ftype} in (?)) and (result = ?)",
                          from_dt,
                          to_dt,
                          event_set.flatten,
                          @tl_options[:tl_result]]
        else
          ftype = @tl_options[:tl_show] == "timeline" ? "event_type" : "miq_event_id"
          where_clause = [") and (timestamp >= ? and timestamp <= ?) and (#{ftype} in (?))",
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

      params2 = where_clause.slice(1,where_clause.length-1)
      params = params.concat(params2)
      @report.where_clause = [cond, *params]
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
    @temp[:timeline] = true if !@report         # need to set this incase @report is not there, when switching between Management/Policy events
    if @report
      unless params[:task_id]                                     # First time thru, kick off the report generate task
        initiate_wait_for_task(:task_id => @report.async_generate_table(:userid => session[:userid]))
        return
      end

      @temp[:timeline] = true
      miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
      @report = miq_task.task_results

      if miq_task.task_results.blank? || miq_task.status != "Ok"  # Check to see if any results came back or status not Ok
        add_flash(I18n.t("flash.error_building_timeline") << miq_task.message, :error)
      else
        @timeline = @timeline_filter = true
        if @report.table.data.length == 0
          add_flash(I18n.t("flash.no_timeline_records_found"), :warning)
        else
          @report.extras[:browser_name] = browser_info("name").downcase
          if is_browser_ie?
            blob = BinaryBlob.new(:name => "timeline_results")
            blob.binary=(@report.to_timeline)
            session[:tl_xml_blob_id] = blob.id
          else
            @temp[:tl_json] = @report.to_timeline
          end
  #         START of TIMELINE TIMEZONE Code
          session[:tl_position] = @report.extras[:tl_position]
  #         session[:tl_position] = format_timezone(@report.extras[:tl_position],Time.zone,"tl")
  #         END of TIMELINE TIMEZONE Code
        end
      end
    end
  end

end
