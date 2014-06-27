class MiqCapacityController < ApplicationController
  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'utilization'
  end

  def utilization
    @breadcrumbs = []
    @sb[:open_tree_nodes] ||= []
    self.x_active_tree = 'utilization_tree'
    util_build_tree(:utilization, :utilization_tree)
    @accords = [{
      :name      => "enterprise",
      :title     => "Utilization",
      :container => "utilization_tree_div",
      :image     => "enterprise"
    }]

    @explorer = true
    @collapse_c_cell = true
    @sb[:active_tab] = "summary"
    self.x_node = ""
    @sb[:util] = {}            # reset existing values
    @sb[:util][:options] = {}  # reset existing values
    get_time_profiles # Get time profiles list (global and user specific)

    # Get the time zone from the time profile, if one is in use
    if @sb[:util][:options][:time_profile]
      tp = TimeProfile.find_by_id(@sb[:util][:options][:time_profile])
      set_time_profile_vars(tp, @sb[:util][:options])
    else
      set_time_profile_vars(selected_time_profile_for_pull_down, @sb[:util][:options])
    end

    @spin_msg = "Generating utilization data..."
    @ajax_action = "util_chart_chooser"
    render :layout => "explorer"
  end

  def bottlenecks
    @breadcrumbs = []
    @sb[:open_tree_nodes] ||= []
    @explorer = true
    @collapse_c_cell = true
    @layout = "miq_capacity_bottlenecks"
    self.x_active_tree = 'bottlenecks_tree'
    util_build_tree(:bottlenecks, :bottlenecks_tree)
    @accords = [{:name => "bottlenecks", :title => "Bottlenecks", :container => "bottlenecks_tree_div", :image => "enterprise"}]

    @sb[:active_tab] = "summary"
    self.x_node ||= ""
    @sb[:bottlenecks] ||= {}  # Leave existing values
    @timeline = true

    if @sb[:bottlenecks] && @sb[:bottlenecks][:report]
      bottleneck_tl_to_xml      # Use existing report to generate timeline
    else
      bottleneck_get_node_info(x_node)  if x_node != "" # Get the bottleneck info for the tree node
    end
    render :layout => "explorer"
  end

  def waste
    @breadcrumbs = Array.new
    @layout = "miq_capacity_waste"
  end

  def planning
    @breadcrumbs = Array.new
    @explorer = true
    @accords = [{:name=>"planning", :title=>"Planning Options", :container=>"planning_options_div"}]

    @collapse_c_cell = true
    self.x_active_tree = nil
    @sb[:active_tab] = "summary"
    @layout = "miq_capacity_planning"
    respond_to do |format|
      format.js do
        if params[:button] == "submit"
          vm_opts = VimPerformancePlanning.vm_default_options(@sb[:planning][:options][:vm_mode])
          unless (vm_opts[:cpu] && @sb[:planning][:options][:trend_cpu]) ||         # Check that at least one required metric is checked
                  (vm_opts[:vcpus] && @sb[:planning][:options][:trend_vcpus]) ||
                  (vm_opts[:memory] && @sb[:planning][:options][:trend_memory]) ||
                  (vm_opts[:storage] && @sb[:planning][:options][:trend_storage])
            add_flash(I18n.t("flash.edit.at_least_1.selected", :field=>"VM Options"), :error)
            render :update do |page|                    # Use JS to update the display
              page.replace("planning_options_div", :partial=>"planning_options")
              page << "miqSparkle(false);"
            end
          else
            perf_planning_gen_data
            @sb[:planning][:options][:submitted_vm_mode] = @sb[:planning][:options][:vm_mode] # Save for display
            if @sb[:planning][:rpt]
              planning_replace_right_cell
            else
              if @sb[:planning][:no_data] # to prevent double render error, making sure it's not wait_for_task transaction
                add_flash(I18n.t("flash.capacity.utilization_data_not_available"), :warning)
                render :update do |page|
                  page.replace("planning_options_div", :partial=>"planning_options")
                  page << "miqSparkle(false);"
                end
              end
            end
          end
        else  # No params, first time in or reset pressed
          planning_build_options
        end
      end
      format.html do                # HTML
        planning_build_options
        render :layout => "explorer"
      end
    end
  end

  def change_tab
    @sb[:active_tab] = params[:tab_id]
    if x_active_tree == :bottlenecks_tree && @sb[:active_tab] == "summary"
      #build timeline data when coming back to Summary tab for bottlenecks
      bottleneck_get_node_info(x_node)
    end
    if x_active_tree != :bottlenecks_tree
      v_buttons, v_xml = build_toolbar_buttons_and_xml("miq_capacity_view_tb")
    end
    render :update do |page|                      # Use JS to update the display
      if x_active_tree != :bottlenecks_tree
        page << "if($('view_buttons_div'))$('view_buttons_div').show();" if v_buttons && v_xml
        page << javascript_for_toolbar_reload('view_tb', v_buttons, v_xml) if v_buttons && v_xml
        page << "dhxLayoutB.cells('a').expand();"
      end
      if x_active_tree == :bottlenecks_tree && @sb[:active_tab] == "summary"
        #need to replace timeline div incase it wasn't there earlier
        page.replace("tl_div", :partial=>"bottlenecks_tl_detail")
      end
      # FIXME: we don't need the reload here for the flash charts
      page << Charting.js_load_statement
      page << "miqSparkle(false);"
    end
  end

  def planning_option_changed
    if params[:filter_typ]
      @sb[:planning][:vms] = nil
      @sb[:planning][:options][:chosen_vm] = nil
      @sb[:planning][:options][:filter_typ] = params[:filter_typ] == "<Choose>" ? nil : params[:filter_typ]
      @sb[:planning][:options][:filter_value] = nil
      if params[:filter_typ] == "all"
        @sb[:planning][:vms] = Hash.new
        find_filtered(Vm, :all).sort{|a,b| a.name.downcase<=>b.name.downcase}.each{|e|@sb[:planning][:vms][e.id.to_s] = e.name}
      end
    end
    if params[:filter_value]
      @sb[:planning][:vms] = nil
      @sb[:planning][:options][:chosen_vm] = nil
      if params[:filter_value] == "<Choose>"
        @sb[:planning][:options][:filter_value] = nil
      else
        @sb[:planning][:options][:filter_value] = params[:filter_value]
        @sb[:planning][:vms] = Hash.new
        if @sb[:planning][:options][:filter_value]
          case @sb[:planning][:options][:filter_typ]
          when "host"
            vms, count = Host.find(@sb[:planning][:options][:filter_value]).find_filtered_children("vms")
            vms.each{|v|@sb[:planning][:vms][v.id.to_s] = v.name}
          when "ems"
            vms, count = ExtManagementSystem.find(@sb[:planning][:options][:filter_value]).find_filtered_children("vms")
            vms.each{|v|@sb[:planning][:vms][v.id.to_s] = v.name}
          when "cluster"
            vms, count = EmsCluster.find(@sb[:planning][:options][:filter_value]).find_filtered_children("all_vms")
            vms.each{|v|@sb[:planning][:vms][v.id.to_s] = v.name}
          when "filter"
            s = MiqSearch.find(@sb[:planning][:options][:filter_value])     # Get the chosen search filter
            s.options ||=  Hash.new                                         # Create options as a Hash
            s.options[:userid] = session[:userid]                           # Set the userid
            s.options[:results_format] = :objects                           # Return objects, not ids
            vms, attrs = s.search                                           # Get the VM objects and search attributes
            vms.each{|v|@sb[:planning][:vms][v.id.to_s] = v.name}   # Add the VMs to the pulldown hash
          end
        end
      end
    end
    @sb[:planning][:options][:chosen_vm] = params[:chosen_vm] == "<Choose>" ? nil : params[:chosen_vm] if params[:chosen_vm]
    @sb[:planning][:options][:days] = params[:trend_days].to_i if params[:trend_days]
    @sb[:planning][:options][:vm_mode] = VALID_PLANNING_VM_MODES[params[:vm_mode]] if params[:vm_mode]
    @sb[:planning][:options][:trend_cpu] = (params[:trend_cpu] == "1") if params[:trend_cpu]
    @sb[:planning][:options][:trend_vcpus] = (params[:trend_vcpus] == "1") if params[:trend_vcpus]
    @sb[:planning][:options][:trend_memory] = (params[:trend_memory] == "1") if params[:trend_memory]
    @sb[:planning][:options][:trend_storage] = (params[:trend_storage] == "1") if params[:trend_storage]
    @sb[:planning][:options][:tz] = params[:planning_tz] if params[:planning_tz]
    if params.has_key?(:time_profile)
      tp = TimeProfile.find(params[:time_profile]) unless params[:time_profile].blank?
      @sb[:planning][:options][:time_profile] = params[:time_profile].blank? ? nil : params[:time_profile].to_i
      @sb[:planning][:options][:time_profile_tz] = params[:time_profile].blank? ? nil : tp.tz
      @sb[:planning][:options][:time_profile_days] = params[:time_profile].blank? ? nil : tp.days
    end
    if params[:target_typ]
      @sb[:planning][:options][:target_typ] = params[:target_typ]
      @sb[:planning][:options][:target_filters] = Hash.new
      MiqSearch.find_all_by_db(@sb[:planning][:options][:target_typ]).each{|ms|@sb[:planning][:options][:target_filters][ms.id.to_s] = ms.description}
      @sb[:planning][:options][:target_filter] = nil
    end
    @sb[:planning][:options][:target_filter] = params[:target_filter].blank? ? nil : params[:target_filter] if params.has_key?(:target_filter)
    @sb[:planning][:options][:limit_cpu] = params[:limit_cpu].to_i if params[:limit_cpu]
    @sb[:planning][:options][:limit_vcpus] = params[:limit_vcpus].to_i if params[:limit_vcpus]
    @sb[:planning][:options][:limit_memory] = params[:limit_memory].to_i if params[:limit_memory]
    @sb[:planning][:options][:limit_storage] = params[:limit_storage].to_i if params[:limit_storage]
    @sb[:planning][:options][:display_vms] = params[:display_vms].blank? ? nil : params[:display_vms].to_i if params.has_key?(:display_vms)

    @sb[:planning][:options][:values][:cpu] = params[:trend_cpu_val].to_i if params[:trend_cpu_val]
    @sb[:planning][:options][:values][:vcpus] = params[:trend_vcpus_val].to_i if params[:trend_vcpus_val]
    @sb[:planning][:options][:values][:memory] = params[:trend_memory_val].to_i if params[:trend_memory_val]
    @sb[:planning][:options][:values][:storage] = params[:trend_storage_val].to_i if params[:trend_storage_val]

    planning_get_vm_values if params[:chosen_vm] ||       # Refetch the VM values if any of these options change
                              params[:vm_mode] ||
                              params[:trend_days] ||
                              params[:tz] ||
                              params[:time_profile]

    @sb[:planning][:vm_opts] = VimPerformancePlanning.vm_default_options(@sb[:planning][:options][:vm_mode])
    unless (@sb[:planning][:vm_opts][:cpu] && @sb[:planning][:options][:trend_cpu]) ||          # Check that at least one required metric is checked
            (@sb[:planning][:vm_opts][:vcpus] && @sb[:planning][:options][:trend_vcpus]) ||
            (@sb[:planning][:vm_opts][:memory] && @sb[:planning][:options][:trend_memory]) ||
            (@sb[:planning][:vm_opts][:storage] && @sb[:planning][:options][:trend_storage])
      add_flash(I18n.t("flash.edit.at_least_1.selected", :field=>"VM Options"), :error)
      @sb[:planning][:options][:trend_cpu] = true if params[:trend_cpu]
      @sb[:planning][:options][:trend_vcpus] = true if params[:trend_vcpus]
      @sb[:planning][:options][:trend_memory] = true if params[:trend_memory]
      @sb[:planning][:options][:trend_storage] = true if params[:trend_storage]
    end
    if params.has_key?(:display_vms)
      perf_planning_gen_data
      planning_replace_right_cell
    else
      render :update do |page|                    # Use JS to update the display
        unless params[:trend_cpu_val] ||          # Don't replace the div when input fields change
                params[:trend_vcpus_val] ||
                params[:trend_memory_val] ||
                params[:trend_storage_val]
          page.replace("planning_options_div", :partial=>"planning_options")
        end
        session[:changed] = @sb[:planning][:options][:chosen_vm] || @sb[:planning][:options][:vm_mode] == :manual
        page << javascript_for_miq_button_visibility(session[:changed])
      end
    end
  end

  # Send the current planning report data in text, CSV, or PDF
  def planning_report_download
    profile = Array.new
    profile.push("CPU #{@sb[:planning][:rpt].extras[:vm_profile][:cpu]}") if @sb[:planning][:rpt].extras[:vm_profile][:cpu]
    profile.push("RAM #{@sb[:planning][:rpt].extras[:vm_profile][:memory]}") if @sb[:planning][:rpt].extras[:vm_profile][:memory]
    profile.push("Disk #{@sb[:planning][:rpt].extras[:vm_profile][:storage]}") if @sb[:planning][:rpt].extras[:vm_profile][:storage]
    @sb[:planning][:rpt].title = "Counts of VMs (#{profile.join(", ")})"
    filename = "VM Counts per #{ui_lookup(:model=>@sb[:planning][:options][:target_typ])}"
    disable_client_cache
    case params[:typ]
    when "txt"
      send_data(@sb[:planning][:rpt].to_text,
        :filename => "#{filename}.txt" )
    when "csv"
      send_data(@sb[:planning][:rpt].to_csv,
        :filename => "#{filename}.csv" )
    when "pdf"
      render_pdf(@sb[:planning][:rpt])
    end
  end

  def accordion_select
#   self.x_active_tree = params[:id]
    util_get_node_info(x_node)
    util_replace_right_cell(@nodetype)
  end

  # Process changes to capacity charts
  def util_chart_chooser
    unless params[:task_id] # Only do this first time thru
      @sb[:util][:options][:chart_date] = params[:miq_date_1] if params[:miq_date_1]
      @sb[:util][:options][:chart_date] = params[:miq_date_2] if params[:miq_date_2]
      @sb[:util][:options][:days] = params[:details_days] if params[:details_days]
      @sb[:util][:options][:days] = params[:report_days] if params[:report_days]
      @sb[:util][:options][:days] = params[:summ_days] if params[:summ_days]
      @sb[:util][:options][:tz] = params[:details_tz] if params[:details_tz]
      @sb[:util][:options][:tz] = params[:report_tz] if params[:report_tz]
      @sb[:util][:options][:tz] = params[:summ_tz] if params[:summ_tz]
      @sb[:util][:options][:tag] = params[:details_tag] == "<None>" ? nil : params[:details_tag] if params[:details_tag]
      @sb[:util][:options][:tag] = params[:report_tag] == "<None>" ? nil : params[:report_tag] if params[:report_tag]
      @sb[:util][:options][:tag] = params[:summ_tag] == "<None>" ? nil : params[:summ_tag] if params[:summ_tag]
      @sb[:util][:options][:index] = params[:chart_idx] == "clear" ? nil : params[:chart_idx] if params[:chart_idx]
      if params.has_key?(:details_time_profile) || params.has_key?(:report_time_profile) || params.has_key?(:summ_time_profile)
        @sb[:util][:options][:time_profile] = params[:details_time_profile].blank? ? nil : params[:details_time_profile].to_i if params.has_key?(:details_time_profile)
        @sb[:util][:options][:time_profile] = params[:report_time_profile].blank? ? nil : params[:report_time_profile].to_i if params.has_key?(:report_time_profile)
        @sb[:util][:options][:time_profile] = params[:summ_time_profile].blank? ? nil : params[:summ_time_profile].to_i if params.has_key?(:summ_time_profile)
        tp = TimeProfile.find(@sb[:util][:options][:time_profile]) unless @sb[:util][:options][:time_profile].blank?
        @sb[:util][:options][:time_profile_tz] = @sb[:util][:options][:time_profile].blank? ? nil : tp.tz
        @sb[:util][:options][:time_profile_days] = @sb[:util][:options][:time_profile].blank? ? nil : tp.days
      end
    end
    if x_node != ""
      util_get_node_info(x_node, "n")
      perf_util_daily_gen_data("n")
    end
    @right_cell_text ||= "Utilization Summary"
    util_replace_right_cell(@nodetype) unless @waiting        # Draw right side if task is done
  end

  # Send the current utilization report data in text, CSV, or PDF
  def util_report_download
    report = MiqReport.new({:title=>@sb[:util][:title],
                            :cols=>["section", "item", "value"],
                            :col_order=>["section", "item", "value"],
                            :headers=>["Section","Item", "Value"],
                            :sortby=>["section"],
                            :extras=>{},
                            :group=>"y"
                          })
    report.db = "MetricRollup"
    report.table = MiqReportable.hashes2table(util_summ_hashes, :only=>report.cols)
    filename = report.title
    disable_client_cache
    case params[:typ]
    when "txt"
      send_data(report.to_text,
        :filename => "#{filename}.txt" )
    when "csv"
      send_data(report.to_csv,
        :filename => "#{filename}.csv" )
    when "pdf"
      render_pdf(report)
    end
  end

  def optimize_tree_select
    if params[:id]                                            # First time thru async method, grab id parm info
      @refresh = (x_node == "")
      self.x_node = params[:id]
    end
    if x_active_tree == :utilization_tree
      @sb[:util][:options][:tag] = nil  # Reset any tag
      util_get_node_info(x_node)
      perf_util_daily_gen_data
      util_replace_right_cell(@nodetype) unless @waiting      # Draw right side if task is done
    elsif x_active_tree == :bottlenecks_tree
      if @refresh  #need to set tl_options if node was "" initially
        bottleneck_get_node_info(x_node)
      else
        bottleneck_get_node_info(x_node,"n")
      end
      bottleneck_replace_right_cell
    end
  end

  # Process changes to timeline selection
  def bottleneck_tl_chooser
    @sb[:bottlenecks][:tl_options][:filter1] = params["tl_summ_fl_grp1"] if params["tl_summ_fl_grp1"]
    @sb[:bottlenecks][:tl_options][:filter1] = params["tl_report_fl_grp1"] if params["tl_report_fl_grp1"]
    @sb[:bottlenecks][:tl_options][:hosts] = params["tl_summ_hosts"] == "1" if params.has_key?("tl_summ_hosts")
    @sb[:bottlenecks][:tl_options][:hosts] = params["tl_report_hosts"] == "1" if params.has_key?("tl_report_hosts")
    @sb[:bottlenecks][:tl_options][:tz] = params["tl_summ_tz"] if params["tl_summ_tz"]
    @sb[:bottlenecks][:tl_options][:tz] = params["tl_report_tz"] if params["tl_report_tz"]
    bottleneck_show_timeline("n")
    bottleneck_replace_right_cell
  end

  private ############################

  # Parse a tree node and set the @nodetype and @record vars
  def get_nodetype_and_record(treenodeid)
    #@nodetype, nodeid = treenodeid.split("-").last.split("_")
    @nodetype, nodeid = treenodeid.split("-")
    node_ids = Hash.new
    treenodeid.split("-").each do |p|
      node_ids[p.split("_").first] = p.split("_").last                    # Create a hash of all record ids represented by the selected tree node
    end
    @sb[:node_ids] ||= Hash.new
    @sb[:node_ids][x_active_tree] = node_ids
    case @nodetype
    when "root"
      @record = MiqEnterprise.my_enterprise
    when "mr" # Region
      @record = MiqRegion.find_by_id(from_cid(nodeid))
    when "e"  # Mgmt Sys
      @record = ExtManagementSystem.find_by_id(from_cid(nodeid))
    when "c"  # Cluster
      @record = EmsCluster.find_by_id(from_cid(nodeid))
    when "h"  # Host
      @record = Host.find_by_id(from_cid(nodeid))
    when "ds" # Storage
      @record = Storage.find_by_id(from_cid(nodeid))
    end
  end

  # Get all info for the node about to be displayed
  def util_get_node_info(treenodeid, refresh=nil)
    treenodeid = valid_active_node(treenodeid)
    get_nodetype_and_record(treenodeid)
    @right_cell_text = @record.class.base_class.to_s == "MiqEnterprise" ?
      I18n.t("cell_header.model", :model => ui_lookup(:model => "MiqEnterprise")) :
      I18n.t("cell_header.model_record_typ", :model => ui_lookup(:model => @record.class.base_class.to_s), :name => @record.name, :typ => "Utilization Trend Summary")
    @sb[:util][:title] = @right_cell_text
    @right_cell_text += " - Filtered by #{@sb[:util][:tags][@sb[:util][:options][:tag]]}" unless @sb[:util][:options].nil? || @sb[:util][:options][:tag].blank?

    # Get start/end dates in selected timezone
    tz = @sb[:util][:options][:time_profile_tz] || @sb[:util][:options][:tz]  # Use time profile tz or chosen tz, if no profile tz
    s, e = @record.first_and_last_capture
    return if s.nil?
    s = s.in_time_zone(tz)
    e = e.in_time_zone(tz)
    # Eliminate partial start or end days
    s = s.hour == 00 ? s : s + 1.day
    e = e.hour < 23 ? e - 1.day : e
    return if s > e                                               # Don't have a full day's data
    sdate = create_time_in_tz("#{s.year}-#{s.month}-#{s.day} 00", tz) # Start at midnight of start date
    edate = create_time_in_tz("#{e.year}-#{e.month}-#{e.day} 23", tz) # End at 11pm of start date

    unless (refresh == "n" || params[:refresh] == "n") && @sb[:util][:options] && @sb[:util][:options][:model] == @record.class.base_class.to_s
      @sb[:util][:options] ||= Hash.new
      @sb[:util][:options][:typ] = "Daily"
      @sb[:util][:options][:days] ||= "7"
      @sb[:util][:options][:model] = @record.class.base_class.to_s
      @sb[:util][:options][:record_id] = @record.id
    end
    trenddate = edate - (@sb[:util][:options][:days].to_i).days + 1.hours # Get trend starting date
    sdate = sdate > trenddate ? sdate : trenddate                   # Use trend date, unless earlier than first date
    if @sb[:util][:options][:chart_date]                            # Clear chosen chart date if out of trend range
      cdate = create_time_in_tz(@sb[:util][:options][:chart_date], tz)  # Get chart date at midnight in time zone
      if (cdate < sdate || cdate > edate) || # Reset if chart date is before start date or after end date
        (@sb[:util][:options][:time_profile] && !@sb[:util][:options][:time_profile_days].include?(cdate.wday) )
        @sb[:util][:options][:chart_date] = nil
      end
    end
    @sb[:util][:options][:trend_start] = sdate
    @sb[:util][:options][:trend_end] = edate
    @sb[:util][:options][:sdate] = [sdate.year.to_s, (sdate.month - 1).to_s, sdate.day.to_s].join(", ") # Start and end dates for calendar control
    @sb[:util][:options][:edate] = [edate.year.to_s, (edate.month - 1).to_s, edate.day.to_s].join(", ")
    @sb[:util][:options][:chart_date] ||= [edate.month, edate.day, edate.year].join("/")

    if @sb[:util][:options][:time_profile]                              # If profile in effect, set date to a valid day in the profile
      @sb[:util][:options][:skip_days] = [0,1,2,3,4,5,6].delete_if{|d| @sb[:util][:options][:time_profile_days].include?(d)}.join(",")
      cdate = @sb[:util][:options][:chart_date].to_date                 # Start at the currently set date
      6.times do                                                        # Go back up to 6 days (try each weekday)
        break if @sb[:util][:options][:time_profile_days].include?(cdate.wday)  # If weekday is in the profile, use it
        cdate -= 1.day                                                  # Drop back 1 day and try again
      end
      @sb[:util][:options][:chart_date] = [cdate.month, cdate.day, cdate.year].join("/")  # Set the new date
    else
      @sb[:util][:options][:skip_days] = nil
    end

    @sb[:util][:options][:days] ||= "7"
    @sb[:util][:options][:ght_type] ||= "hybrid"
    @sb[:util][:options][:chart_type] = :summary
  end

  def util_replace_right_cell(nodetype, replace_trees = [])  # replace_trees can be an array of tree symbols to be replaced
    # Get the tags for this node for the Classification pulldown
    @sb[:util][:tags] = nil unless params[:miq_date_1] || params[:miq_date_2]   # Clear tags unless just changing date
    unless @nodetype == "h" || @nodetype == "s" || params[:miq_date_1] || params[:miq_date_2] # Get the tags for the pulldown, unless host, storage, or just changing the date
      if @sb[:util][:options][:chart_date]
        mm, dd, yy = @sb[:util][:options][:chart_date].split("/")
        end_date = Time.utc(yy, mm, dd, 23, 59, 59)
        @sb[:util][:tags] = VimPerformanceAnalysis.child_tags_over_time_period(
            @record, 'daily',
            {:end_date=>end_date, :days=>@sb[:util][:options][:days].to_i,
             :ext_options=>{:tz=>@sb[:util][:trend_rpt].tz,                     # Add ext_options for tz from rpt object
                            :time_profile=>@sb[:util][:trend_rpt].time_profile}
            }
        )
      end
    end

    util_build_tree(:utilization, :utilization_tree) if replace_trees.include?(:utilization)

    v_buttons, v_xml = build_toolbar_buttons_and_xml("miq_capacity_view_tb")
    presenter = ExplorerPresenter.new(:active_tree => x_active_tree)
    r = proc { |opts| render_to_string(opts) }

    presenter[:extra_js] << 'miq_chart_data = ' + @sb[:util][:chart_data].to_json + ';'

    # clearing out any selection in tree if active node has been reset to "" upon returning to screen or when first time in
    presenter[:clear_selection] = x_node == ''

    if v_buttons && v_xml
      presenter[:set_visible_elements][:view_buttons_div] = true
      presenter[:reload_toolbars][:view] = {:buttons => v_buttons, :xml => v_xml}
    end

    presenter[:expand_collapse_cells][:a] = 'expand'
    presenter[:save_open_states_trees] << :utilization_tree
    presenter[:update_partials][:main_div] = r[:partial => 'utilization_tabs']
    presenter[:right_cell_text] = @right_cell_text
    presenter[:build_calendar]  = {
      :skip_days => @sb[:util][:options][:skip_days],
      :date_from => @sb[:util][:options][:sdate],
      :date_to   => @sb[:util][:options][:edate],
    }

    # FIXME: where is curTab declared?
    presenter[:extra_js] << "curTab = $j('#utilization_tabs.ui-tabs-panel:not(.ui-tabs-hide)');"
    presenter[:extra_js] << "tab = curTab.prop('id');"
    # FIXME: handle or verify the IE/non-IE branch for the flash charts
    presenter[:extra_js] << Charting.js_load_statement(true)

    render :js => presenter.to_html
  end

  def planning_build_options
    @breadcrumbs = Array.new
    @sb[:planning] ||= Hash.new             # Leave existing values
    @sb[:planning] = Hash.new if params[:button] == "reset" # Clear everything on reset
    @sb[:planning][:options] ||= Hash.new   # Leave existing values
    @sb[:planning][:options][:days] ||= 7
    @sb[:planning][:options][:vm_mode] ||= :allocated
    @sb[:planning][:options][:trend_cpu] = true if @sb[:planning][:options][:trend_cpu].nil?
    @sb[:planning][:options][:trend_vcpus] = true if @sb[:planning][:options][:trend_vcpus].nil?
    @sb[:planning][:options][:trend_memory] = true if @sb[:planning][:options][:trend_memory].nil?
    @sb[:planning][:options][:trend_storage] = true if @sb[:planning][:options][:trend_storage].nil?
    @sb[:planning][:options][:tz] ||= session[:user_tz]
    @sb[:planning][:options][:values] ||= Hash.new
    planning_get_vm_values
    get_time_profiles # Get time profiles list (global and user specific)

    # Get the time zone from the time profile, if one is in use
    if @sb[:planning][:options][:time_profile]
      tp = TimeProfile.find_by_id(@sb[:planning][:options][:time_profile])
      set_time_profile_vars(tp, @sb[:planning][:options])
    else
      set_time_profile_vars(selected_time_profile_for_pull_down, @sb[:planning][:options])
    end

    @sb[:planning][:options][:target_typ] ||= "EmsCluster"
    @sb[:planning][:options][:target_filters] = Hash.new
    MiqSearch.find_all_by_db(@sb[:planning][:options][:target_typ]).each{|s|@sb[:planning][:options][:target_filters][s.id.to_s] = s.description}
    @sb[:planning][:options][:limit_cpu] ||= 90
    @sb[:planning][:options][:limit_vcpus] ||= 10
    @sb[:planning][:options][:limit_memory] ||= 90
    @sb[:planning][:options][:limit_storage] ||= 90
    @sb[:planning][:options][:display_vms] ||= 100

    @sb[:planning][:emss] = Hash.new
    find_filtered(ExtManagementSystem, :all).each{|e|@sb[:planning][:emss][e.id.to_s] = e.name}
    @sb[:planning][:clusters] = Hash.new
    find_filtered(EmsCluster, :all).each{|e|@sb[:planning][:clusters][e.id.to_s] = e.name}
    @sb[:planning][:hosts] = Hash.new
    find_filtered(Host, :all).each{|e|@sb[:planning][:hosts][e.id.to_s] = e.name}
    @sb[:planning][:datastores] = Hash.new
    find_filtered(Storage, :all).each{|e|@sb[:planning][:datastores][e.id.to_s] = e.name}
    @sb[:planning][:vm_filters] = Hash.new
    MiqSearch.find_all_by_db("Vm").each{|s|@sb[:planning][:vm_filters][s.id.to_s] = s.description}
    @right_cell_text = "Planning Summary"
    if params[:button] == "reset"
      session[:changed] = false
      add_flash(I18n.t("flash.capacity.planning_reset"))
      v_buttons, v_xml = build_toolbar_buttons_and_xml("miq_capacity_view_tb")
      render :update do |page|  # Redraw the screen
        page << "if($('view_buttons_div'))$('view_buttons_div').show();" if v_buttons && v_xml
        page << javascript_for_toolbar_reload('view_tb', v_buttons, v_xml) if v_buttons && v_xml
        page << "dhxLayoutB.cells('a').expand();"
        page << javascript_for_miq_button_visibility(session[:changed])
        page.replace("planning_options_div", :partial=>"planning_options")
        page.replace_html("main_div", :partial=>"planning_tabs")
      end
    end
    if @sb[:planning] && @sb[:planning][:chart_data]  # If planning charts already exist
      @perf_record = MiqEnterprise.first
    end
  end

  # Get the metric values for the selected VM based on the mode
  def planning_get_vm_values
    return if @sb[:planning][:options][:vm_mode] == :manual
    if @sb[:planning][:options][:chosen_vm]
      @sb[:planning][:options][:values] = Hash.new
      vm_options = VimPerformancePlanning.vm_default_options(@sb[:planning][:options][:vm_mode])
      VimPerformancePlanning.vm_metric_values(Vm.find(@sb[:planning][:options][:chosen_vm]),
                                              { :vm_options=>vm_options,
                                                :range=>{
                                                  :days=>@sb[:planning][:options][:days],
                                                  :end_date=>perf_planning_end_date
                                                },
                                                :tz=>@sb[:planning][:options][:tz],
                                                :time_profile_id=>@sb[:planning][:options][:time_profile]
                                              })
      vm_options.each do |k,v|
        unless v.nil?
          if k == :storage
            @sb[:planning][:options][:values][k] = (v[:value].to_i/1.gigabyte).round
          else
            @sb[:planning][:options][:values][k] = v[:value].to_i.round
          end
        end
      end
    end
  end

  def planning_replace_right_cell
    v_buttons, v_xml = build_toolbar_buttons_and_xml("miq_capacity_view_tb")
    presenter = ExplorerPresenter.new(:active_tree => @sb[:active_tree])
    r = proc { |opts| render_to_string(opts) }

    presenter[:extra_js] << 'miq_chart_data = ' + @sb[:planning][:chart_data].to_json + ';'

    if v_buttons && v_xml
      presenter[:set_visible_elements][:view_buttons_div] = true
      presenter[:reload_toolbars][:view] = {:buttons => v_buttons, :xml => v_xml}
    end

    presenter[:expand_collapse_cells][:a] = 'expand'
    presenter[:update_partials][:main_div] = r[:partial => 'planning_tabs']
    presenter[:replace_cell_text] = I18n.t("cell_header.best_fit_model",
                                           :model=>@sb[:planning][:options][:target_typ] == 'Host' ? 'Hosts' : 'Clusters')

    presenter[:extra_js] << "curTab = $j('#planning_tabs.ui-tabs-panel:not(.ui-tabs-hide)');"
    presenter[:extra_js] << "tab = curTab.prop('id');"
    presenter[:extra_js] << Charting.js_load_statement(true)

    render :js => presenter.to_html
  end

  def bottleneck_replace_right_cell
    presenter = ExplorerPresenter.new(:active_tree => x_active_tree)
    r = proc { |opts| render_to_string(opts) }

    presenter[:osf_node] = x_node
    presenter[:update_partials][:main_div] = r[:partial => 'bottlenecks_tabs']
    presenter[:replace_partials][:tl_div]  = r[:partial => 'bottlenecks_tl_detail']
    presenter[:build_calendar] = true
    presenter[:save_open_states_trees] << :bottlenecks_tree
    presenter[:right_cell_text] = @right_cell_text

    presenter[:extra_js] << "curTab = $j('#bottlenecks_tabs.ui-tabs-panel:not(.ui-tabs-hide)');"
    presenter[:extra_js] << "tab = curTab.prop('id');"

    render :js => presenter.to_html
  end

  def bottleneck_get_node_info(treenodeid, refresh=nil)
    treenodeid = valid_active_node(treenodeid)
    @timeline = true
    @lastaction = "bottleneck_show_timeline"

    get_nodetype_and_record(treenodeid)
    @right_cell_text = @record.class.base_class.to_s == "MiqEnterprise" ?
        I18n.t("cell_header.model", :model => ui_lookup(:model => "MiqEnterprise")) :
        I18n.t("cell_header.model_record_typ", :model => ui_lookup(:model => @record.class.base_class.to_s), :name => @record.name, :typ => "Bottlenecks Summary")

    # Get the where clause to limit records to the selected tree node (@record)
    @sb[:bottlenecks][:objects_where_clause] = nil
    unless @nodetype == "root"
      # Call method to get where clause to filter child objects
      @sb[:bottlenecks][:objects_where_clause] = BottleneckEvent.event_where_clause(@record)
    end
    @sb[:active_tab] = "summary"      #reset tab back to first tab when node is changed in the tree
    bottleneck_show_timeline(refresh)                 # Create the timeline report
    drop_breadcrumb( {:name=>"Activity", :url=>"/miq_capacity/bottlenecks/?refresh=n"} )
  end

  def bottleneck_show_timeline(refresh = nil)
    unless (refresh == "n" || params[:refresh] == "n") #||
      #store object_where_clause in @temp so it can be retrieved after intializing @sb[:bottlenecks]
      @temp[:objects_where_clause] = @sb[:bottlenecks][:objects_where_clause]
      @sb[:bottlenecks] = Hash.new
      #restore object_where_clause from @temp
      @sb[:bottlenecks][:objects_where_clause] = @temp[:objects_where_clause]
      @sb[:bottlenecks][:tl_options] = Hash.new
      @sb[:bottlenecks][:tl_options][:model] = "BottleNeck"
      @sb[:bottlenecks][:tl_options][:tz] = session[:user_tz]
    end
    @sb[:bottlenecks][:groups] = Array.new
    @tl_groups_hash = Hash.new
    BOTTLENECK_TL_ETYPE_GROUPS.each do |gname,list|
      @sb[:bottlenecks][:groups].push(list[:name].to_s)
      @tl_groups_hash[gname] ||= Array.new
      @tl_groups_hash[gname].concat(list[:detail]).uniq!
    end
    if @sb[:bottlenecks][:tl_options][:filter1].blank?
      @sb[:bottlenecks][:tl_options][:filter1] = "ALL"
    end

    if params["tl_summ_tz"] || params["tl_report_tz"] # Don't regenerate the report if only timezone changed
      @sb[:bottlenecks][:report].tz = @sb[:bottlenecks][:tl_options][:tz] # Set the new timezone
      @title = @sb[:bottlenecks][:report].title
      bottleneck_tl_to_xml
    else
      @sb[:bottlenecks][:report] = MiqReport.new(YAML::load(File.open("#{TIMELINES_FOLDER}/miq_reports/tl_bottleneck_events.yaml")))
      @sb[:bottlenecks][:report].tz = @sb[:bottlenecks][:tl_options][:tz] # Set the new timezone
      @title = @sb[:bottlenecks][:report].title

      event_set = Array.new
      if @sb[:bottlenecks][:tl_options][:filter1] != "ALL"
        @tl_groups_hash.each do |name,fltr|
          if name.to_s == @sb[:bottlenecks][:tl_options][:filter1].to_s
            fltr.each do |f|
              event_set.push(f) unless event_set.include?(f)
            end
          end
        end
      else
        @tl_groups_hash.each do |name,fltr|
          fltr.each do |f|
            event_set.push(f) unless event_set.include?(f)
          end
        end
      end

      if @sb[:bottlenecks][:objects_where_clause]
        @sb[:bottlenecks][:report].where_clause = "(#{@sb[:bottlenecks][:objects_where_clause]}) AND (#{BottleneckEvent.send(:sanitize_sql_for_conditions, ["event_type in (?)", event_set])})"
      else
        @sb[:bottlenecks][:report].where_clause = BottleneckEvent.send(:sanitize_sql_for_conditions, ["event_type in (?)", event_set])
      end

      # Don't include Host resource types based on option - exclude host and storage nodes
      unless @sb[:bottlenecks][:tl_options][:hosts] ||
          ["h","s"].include?(x_node.split("-").last.split("_").first)
        @sb[:bottlenecks][:report].where_clause = "(#{@sb[:bottlenecks][:report].where_clause}) AND resource_type != 'Host'"
      end

      begin
          @sb[:bottlenecks][:report].generate_table(:userid => session[:userid])
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_building_timeline") << bang.message, :error)
      else
        bottleneck_tl_to_xml
      end
    end
  end

  # Create timeline xml from report data
  def bottleneck_tl_to_xml
    @timeline = true
    if @sb[:bottlenecks][:report].table.data.length == 0
      add_flash(I18n.t("flash.no_timeline_records_found"), :warning)
    else
      tz = @sb[:bottlenecks][:report].tz ? @sb[:bottlenecks][:report].tz : Time.zone
      @sb[:bottlenecks][:report].extras[:browser_name] = browser_info("name").downcase
      if is_browser_ie?
        blob = BinaryBlob.new(:name => "timeline_results")
        blob.binary=(@sb[:bottlenecks][:report].to_timeline)
        session[:tl_xml_blob_id] = blob.id
      else
        @temp[:tl_json] = @sb[:bottlenecks][:report].to_timeline
      end
#         START of TIMELINE TIMEZONE Code
#     session[:tl_position] = @sb[:bottlenecks][:report].extras[:tl_position]
      session[:tl_position] = format_timezone(@sb[:bottlenecks][:report].extras[:tl_position],tz,"tl")
#         END of TIMELINE TIMEZONE Code
    end
  end

  def send_button_changes
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      if @action_type_changed || @tag_selected || @snmp_trap_refresh
        page.replace("action_options_div", :partial=>"action_options")
      elsif @alert_refresh
        page.replace("alert_details_div", :partial=>"alert_details")
      end
      if changed != session[:changed]
        session[:changed] = changed
        page << javascript_for_miq_button_visibility(changed)
      end
    end
  end

  def util_build_tree(type, name)
    utilization = TreeBuilderUtilization.new(name, type, @sb)
    @right_cell_text = "#{type == :bottlenecks ? "Bottlenecks": "Utilization"} Summary"
    @temp[name] = utilization.tree_nodes
  end

  # Add the children of a node that is being expanded (autoloaded), called by generic tree_autoload method
  def tree_add_child_nodes(id)
    return x_get_child_nodes(x_active_tree, id)
  end

  # Create an array of hashes from the Utilization summary report tab information
  def util_summ_hashes
    a = Array.new
    @sb[:util][:summary][:info].each{|r| a.push({"section"=>"Basic Info", "item"=>r[0], "value"=>r[1]}) } if @sb[:util][:summary][:info]
    @sb[:util][:summary][:cpu].each{|r| a.push({"section"=>"CPU", "item"=>r[0], "value"=>r[1]}) } if @sb[:util][:summary][:cpu]
    @sb[:util][:summary][:memory].each{|r| a.push({"section"=>"Memory", "item"=>r[0], "value"=>r[1]}) } if @sb[:util][:summary][:memory]
    @sb[:util][:summary][:storage].each{|r| a.push({"section"=>"Disk", "item"=>r[0], "value"=>r[1]}) } if @sb[:util][:summary][:storage]
    return a
  end

  def get_session_data
    @title        = "Utilization"
    @layout     ||= "miq_capacity_utilization"
    @lastaction   = session[:miq_capacity_lastaction]
    @display      = session[:miq_capacity_display]
    @current_page = session[:miq_capacity_current_page]
  end

  def set_session_data
    session[:miq_capacity_lastaction]   = @lastaction
    session[:miq_capacity_current_page] = @current_page
    session[:miq_capacity_display]      = @display unless @display.nil?
  end

end
