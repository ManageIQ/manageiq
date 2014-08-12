class ChargebackController < ApplicationController
  @@fixture_dir = File.join(Rails.root, "db/fixtures")

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  #FIXME -- is INDEX needed ?
  def index
    redirect_to :action => 'explorer'
  end

  def x_button
    @sb[:action] = params[:pressed]
    @_params[:typ] = params[:pressed].split('_').last
    cb_rate_edit if ["chargeback_rates_copy","chargeback_rates_edit","chargeback_rates_new"].include?(params[:pressed])
    cb_rates_delete if params[:pressed] == "chargeback_rates_delete"
  end

  def accordion_select
    self.x_active_accord = params[:id]
    self.x_active_tree   = "#{params[:id]}_tree"
    get_node_info(x_node)
    replace_right_cell
  end

  def tree_select
    self.x_active_tree = params[:tree] if params[:tree]
    self.x_node = params[:id]
    get_node_info(x_node)
    replace_right_cell
  end

  def explorer
    @breadcrumbs = []
    @explorer    = true
    @trees       = []
    @built_trees = []
    @accords     = []

    if role_allows(:feature=>"chargeback_reports")
      self.x_active_tree   ||= 'cb_reports_tree'
      self.x_active_accord ||= 'cb_reports'
      tree = cb_rpts_build_tree
      cb_rpt_build_folder_nodes if tree.x_node == "root"
      @built_trees << tree
      @accords << {:name => "cb_reports", :title => "Reports", :container => "cb_reports_tree_div"}
    end
    if role_allows(:feature => "chargeback_rates")
      self.x_active_tree   ||= 'cb_rates_tree'
      self.x_active_accord ||= 'cb_rates'
      @built_trees << cb_rates_build_tree
      @accords << {:name => "cb_rates", :title => "Rates", :container => "cb_rates_tree_div"}
    end
    if role_allows(:feature => "chargeback_assignments")
      self.x_active_tree   ||= 'cb_assignments_tree'
      self.x_active_accord ||= 'cb_assignments'
      @built_trees << cb_assignments_build_tree
      @accords << {:name => "cb_assignments", :title => "Assignments", :container => "cb_assignments_tree_div"}
    end

    if params[:accordion]
      self.x_active_tree   = "#{params[:accordion]}_tree"
      self.x_active_accord = params[:accordion]
    end

    @sb[:open_tree_nodes] ||= []

    cb_rates_list
    @right_cell_text = case x_active_tree
    when :cb_rates_tree       then I18n.t("cell_header.all_model_records",:model=>ui_lookup(:models=>"ChargebackRate"))
    when :cb_assignments_tree then I18n.t("cell_header.all_model_records",:model=>"Assignments")
    when :cb_reports_tree     then I18n.t("cell_header.all_model_records",:model=>"Saved Chargeback Reports")
    end
    get_node_info(x_node)

    render :layout => "explorer"
  end

    # Show the main Schedules list view
  def cb_rates_list
    @listicon = "chargeback_rates"
    @force_no_grid_xml = true
    @gtl_type = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                              # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                        # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page          # Set the per page setting for this gtl type
    end
    @sortcol = session[:rates_sortcol] == nil ? 0 : session[:rates_sortcol].to_i
    @sortdir = session[:rates_sortdir] == nil ? "ASC" : session[:rates_sortdir]

    @view, @pages = get_view(ChargebackRate,:conditions=>["rate_type=?",x_node.split('-').last])  # Get the records (into a view) and the paginator

    @current_page = @pages[:current] if @pages != nil  # save the current page number
    session[:rates_sortcol] = @sortcol
    session[:rates_sortdir] = @sortdir

    if !params[:action] && (params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page])
      render :update do |page|                    # Use RJS to update the display
        page.replace("gtl_div", :partial=>"layouts/gtl", :locals=>{:action_url=>"cb_rates_list"})
      end
    end
  end

  def cb_rate_edit
    assert_privileges(params[:pressed]) if params[:pressed]
    case params[:button]
    when "cancel"
      add_flash("#{!@sb[:rate] || @sb[:rate].id.blank? ? I18n.t("flash.add.cancelled", :model=>ui_lookup(:model=>"ChargebackRate")) :
        I18n.t("flash.edit.cancelled", :model=>ui_lookup(:model=>"ChargebackRate"), :name=>@sb[:rate].description)}")
      get_node_info(x_node)
      @sb[:rate] = @sb[:rate_details] = nil
      @edit = session[:edit] = nil  # clean out the saved info
      session[:changed] =  false
      replace_right_cell
    when "save", "add"
      id = params[:id] && params[:button] == "save" ? params[:id] : "new"
      return unless load_edit("cbrate_edit__#{id}","replace_cell__chargeback")
      @sb[:rate] = @edit[:rate] if @edit && @edit[:rate]
      if @edit[:new][:description].nil? || @edit[:new][:description] == ""
        add_flash(I18n.t("flash.edit.field_required", :field=>"Description"), :error)
        replace_right_cell
        return
      end
      @sb[:rate].description = @edit[:new][:description]
      @sb[:rate].rate_type = @edit[:new][:rate_type] if @edit[:new][:rate_type]
      if params[:button] == "add"
        cb_rate_set_record_vars
        @sb[:rate].chargeback_rate_details.replace(@sb[:rate_details])

        if @sb[:rate].save
          AuditEvent.success(build_saved_audit(@sb[:rate], @edit))
          add_flash(I18n.t("flash.add.added",
                          :model=>ui_lookup(:model=>"ChargebackRate"),
                          :name=>@sb[:rate].description))
          @edit = session[:edit] = nil  # clean out the saved info
          session[:changed] =  @changed = false
          get_node_info(x_node)
          replace_right_cell([:cb_rates])
        else
          @sb[:rate].errors.each do |field,msg|
            add_flash("#{field.to_s.capitlize} #{msg}", :error)
          end
          @sb[:rate_details].each do |detail|
            detail.errors.each {|field,msg| add_flash("'#{detail.description}' #{field.to_s.capitlize} #{msg}", :error)}
          end
          @changed = session[:changed] = (@edit[:new] != @edit[:current])
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
        end
      else      # for save button
        cb_rate_set_record_vars
        # Detect errors saving rate details
        rate_detail_error = false
        @sb[:rate_details].each {|detail| rate_detail_error = true if detail.save == false}
        if rate_detail_error==false && @sb[:rate].save
          AuditEvent.success(build_saved_audit(@sb[:rate], @edit))
          add_flash(I18n.t("flash.edit.saved",
                          :model=>ui_lookup(:model=>"ChargebackRate"),
                          :name=>@sb[:rate].description))
          @edit = session[:edit] = nil  # clean out the saved info
          @changed = false
          get_node_info(x_node)
          replace_right_cell([:cb_rates])
        else
          @sb[:rate].errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          @sb[:rate_details].each do |detail|
            detail.errors.each {|field,msg| add_flash("'#{detail.description}' #{field.to_s.capitalize} #{msg}", :error)}
          end
          @changed = session[:changed] = (@edit[:new] != @edit[:current])
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
        end
      end
    when "reset", nil  # Reset or first time in
      obj = find_checked_items                              # editing from list view
      obj[0] = params[:id] if obj.blank? && params[:id]      # editing from show screen
      if params[:typ] == "copy" # if tab was not changed
        session[:changed] = true
        @sb[:rate_details] = Array.new
        rate = ChargebackRate.find(obj[0])
        @sb[:rate] = ChargebackRate.new
        @sb[:rate].description = "Copy of " +  rate.description
        @sb[:rate].rate_type = rate.rate_type
        rate_details = rate.chargeback_rate_details
        # Create new rate detail records for copied rate record
        rate_details.each do |r|
          detail = ChargebackRateDetail.new
          detail.description = r[:description]
          detail.source = r[:source]
          detail.rate = r[:rate]
          detail.per_time = r[:per_time]
          detail.group = r[:group]
          detail.per_unit = r[:per_unit]
          detail.metric = r[:metric]
          @sb[:rate_details].push(detail) unless @sb[:rate_details].include?(detail)
        end
      else
        session[:changed] = false
        @sb[:rate] = params[:typ] == "new" ? ChargebackRate.new : ChargebackRate.find(obj[0])
        @sb[:rate_details] = @sb[:rate].chargeback_rate_details
        if @sb[:rate_details].blank?
          fixture_file = File.join(@@fixture_dir, "chargeback_rates.yml")
          if File.exists?(fixture_file)
            fixture = YAML.load_file(fixture_file)
            fixture.each do |cbr|
              if cbr[:rate_type] == x_node.split('-').last
                rates = cbr.delete(:rates)
                rates.each do |r|
                  detail = ChargebackRateDetail.new
                  detail.description = r[:description]
                  detail.source = r[:source]
                  #detail.rate = r[:rate]
                  #detail.per_time = r[:per_time]
                  detail.rate = ""
                  detail.per_time = "hourly"
                  detail.group = r[:group]
                  detail.per_unit = r[:per_unit]
                  detail.metric = r[:metric]
                  @sb[:rate_details].push(detail) unless @sb[:rate_details].include?(detail)
                end
              end
            end
          end
        end
      end
      @sb[:rate_details].sort!{|a,b| [a[:group].downcase,a[:description].downcase]<=>[b[:group].downcase,b[:description].downcase]}
      cb_rate_set_form_vars
      @in_a_form = true
      if params[:button] == "reset"
        add_flash(I18n.t("flash.edit.reset"), :warning)
      end
      replace_right_cell
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def cb_rate_form_field_changed
    return unless load_edit("cbrate_edit__#{params[:id]}","replace_cell__chargeback")
    cb_rate_get_form_vars
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  def cb_rate_show
    @display = "main"
    @sb[:selected_rate_details] = @record.chargeback_rate_details
    @sb[:selected_rate_details].sort!{|a,b| [a[:group].downcase,a[:description].downcase]<=>[b[:group].downcase,b[:description].downcase]}
    if @record == nil
      redirect_to :action=>"cb_rates_list", :flash_msg=>I18n.t("flash.error_no_longer_exists"), :flash_error=>true
      return
    end
  end

  # Delete all selected or single displayed action(s)
  def cb_rates_delete
    assert_privileges("chargeback_rates_delete")
    rates = []
    if !params[:id] # showing a list
      rates = find_checked_items
      if rates.empty?
        add_flash(I18n.t("flash.no_records_selected_for_delete", :model=>ui_lookup(:models=>"ChargebackRate")), :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
      process_cb_rates(rates, "destroy")  unless rates.empty?
      add_flash(I18n.t("flash.record.deleted_for_records", :model=>ui_lookup(:models=>"ChargebackRate")), :info, true) if ! flash_errors?
      cb_rates_list
      @right_cell_text = I18n.t("cell_header.type_of_model_records",:typ=>x_node,:model=>ui_lookup(:models=>"ChargebackRate"))
      replace_right_cell([:cb_rates])
    else # showing 1 rate, delete it
      if params[:id] == nil || ChargebackRate.find_by_id(params[:id]).nil?
        add_flash(I18n.t("flash.record.no_longer_exists",
                         :model => ui_lookup(:model => "ChargebackRate")), :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      else
        rates.push(params[:id])
      end
      cb_rate = ChargebackRate.find_by_id(params[:id])
      process_cb_rates(rates, "destroy")  if !rates.empty?
      add_flash(I18n.t("flash.record.deleted_for_1_record", :model=>ui_lookup(:model=>"ChargebackRate")), :info, true) if ! flash_errors?
      self.x_node = "xx-#{cb_rate.rate_type}"
      cb_rates_list
      @right_cell_text = I18n.t("cell_header.type_of_model_records",:typ=>x_node.split('-').last,:model=>ui_lookup(:models=>"ChargebackRate"))
      replace_right_cell([:cb_rates])
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def cb_assign_field_changed
    return unless load_edit("cbassign_edit__#{x_node}","replace_cell__chargeback")
    cb_assign_get_form_vars
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      page.replace("cb_assignment_div", :partial=>"cb_assignments") if params[:cbshow_typ] || params[:cbtag_cat]      #only replace if cbshow_typ or cbtag_cat has changed
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  def cb_assign_update
    if params[:button] == "reset"
      get_node_info(x_node)
      add_flash(I18n.t("flash.edit.reset"),:warning)
      replace_right_cell
    else
      return unless load_edit("cbassign_edit__#{x_node}","replace_cell__chargeback")
      cb_assign_set_record_vars
      rate_type = x_node.split('-').last
      begin
        ChargebackRate.set_assignments(rate_type, @edit[:set_assignments])
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"Rate assignments") << bang.message, :error)
        render :update do |page|                    # Use RJS to update the display
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      else
        add_flash(I18n.t("flash.edit.task_saved", :task=>"Rate Assignments"))
        get_node_info(x_node)
        replace_right_cell
      end
    end
  end

  private ############################

  # Build a Chargeback Reports explorer tree
  def cb_rpts_build_tree
    TreeBuilderChargebackReports.new("cb_reports_tree", "cb_reports", @sb)
  end

  def cb_rpts_show_saved_report
    @sb[:last_savedreports_id] = params[:id].split('_').last.split('-').last if params[:id] && params[:id] != "reports"
    cb_rpts_fetch_saved_report(@sb[:last_savedreports_id])
    @sb[:parent_reports] = nil if @report.blank?
  end

  def cb_rpts_fetch_saved_report(id)
    rr = MiqReportResult.find_by_id(from_cid(id.split('-').last))
    if rr.nil?  # Saved report no longer exists
      @report = nil
      return
    end
    @right_cell_text ||= "Saved Chargeback Report [#{rr.name}]"
    if rr.userid != session[:userid]
      add_flash(I18n.t("flash.report.not_authorized_for_user"), :error)
      @temp[:saved_reports] = cb_rpts_get_all_reps(id.split('-')[1])
      return
    else
      @report_result_id = session[:report_result_id] = rr.id
      session[:report_result_runtime]  = rr.last_run_on
      @report = rr.report_results
      session[:rpt_task_id] = nil
      if @report.blank?
        add_flash(I18n.t("flash.report.not_found_schedule_failed", :name=>format_timezone(report.last_run_on,Time.zone,"gtl")), :error)
        @temp[:saved_reports] = cb_rpts_get_all_reps(rr.miq_report_id.to_s)
        rep = MiqReport.find_by_id(rr.miq_report_id)
        if x_active_tree == :cb_reports
          self.x_node = "reports-#{rep.id}"
        else
          @sb[:rpt_menu].each_with_index do |lvl1,i|
            if lvl1[0]  == session[:customer_name]
              lvl1[1].each_with_index do |lvl2,k|
                if lvl2[0].downcase == "custom"
                  @sb[:active_node]["report"] = "reports-#{i}-#{k}-#{lvl2[1].length-1}_#{rep.id}"
                end
               end
            end
          end
        end
        return
      else
        if @report.table && @report.table.data.length == 0
          add_flash(I18n.t("flash.report.no_records_found"), :warning)
        else
          @html = report_first_page(rr)              # Get the first page of the results
          unless @report.graph.blank?
            @zgraph = true
            @ght_type = "hybrid"
          else
            @ght_type = "tabular"
          end
          @report.extras ||= Hash.new                # Create extras hash
          @report.extras[:to_html] ||= @html        # Save the html report
        end
      end
    end
  end

  def get_node_info(node)
    node = valid_active_node(node)
    if x_active_tree == :cb_rates_tree
      if node == "root"
        @sb[:rate] = @record = @sb[:selected_rate_details] = nil
        @right_cell_text = I18n.t("cell_header.all_model_records",:model=>ui_lookup(:models=>"ChargebackRate"))
      elsif ["xx-Compute","xx-Storage"].include?(node)
        @sb[:rate] = @record = @sb[:selected_rate_details] = nil
        @right_cell_text = I18n.t("cell_header.type_of_model_records",:typ=>x_node.split('-').last,:model=>ui_lookup(:models=>"ChargebackRate"))
        cb_rates_list
      else
        @record = ChargebackRate.find(from_cid(node.split('_').last.split('-').last))
        @sb[:action] = nil
        @right_cell_text = I18n.t("cell_header.type_of_model_record",:typ=>@record.rate_type,:model=>ui_lookup(:model=>"ChargebackRate"),:name=>@record.description)
        cb_rate_show
      end
    elsif x_active_tree == :cb_assignments_tree
      if ["xx-Compute","xx-Storage"].include?(node)
        cb_assign_set_form_vars
        @right_cell_text = I18n.t("cell_header.type_of_model_records",:typ=>node.split('-').last,:model=>"Rate Assignments")
      else
        @right_cell_text = I18n.t("cell_header.all_model_records",:model=>"Assignments")
      end
    elsif x_active_tree == :cb_reports_tree
      @nodetype = node.split("-")[0]
      nodeid = node.split("_")
      nodes = x_node.split('_')
      nodes_len = nodes.length

      # On the root node
      if x_node == "root"
        cb_rpt_build_folder_nodes
        @right_cell_div = "reports_list_div"
        @right_cell_text = I18n.t("cell_header.all_model_records",:model=>"Saved Chargeback Reports")
      elsif nodes_len == 2
        # On a saved report node
        cb_rpts_show_saved_report
        if @report
          s = MiqReportResult.find_by_id(from_cid(nodes.last.split('-').last))
          @right_cell_div = "reports_list_div"
          @right_cell_text = I18n.t("cell_header.model_record",:model=>"Saved Chargeback Report",:name=>format_timezone(s.last_run_on,Time.zone,"gtl"))
        else
          add_flash(I18n.t("flash.report.selected_no_longer_exists", :typ=>"Saved Chargeback"), :warning)
          nodes_len = 2  # Force to show the parent node
          self.x_node = nodes[0..1].join("_")
          cb_rpts_build_tree # Rebuild tree
        end
      # On a saved reports parent node
      else
        #saved reports under report node on saved report accordion
        @temp[:saved_reports] = cb_rpts_get_all_reps(nodes[0].split('-')[1])
        unless @temp[:saved_reports].empty?
          @sb[:sel_saved_rep_id] = nodes[1]
          @right_cell_div = "reports_list_div"
          miq_report = MiqReport.find(@sb[:miq_report_id])
          @right_cell_text = I18n.t("cell_header.model_record",:model=>"Saved Chargeback Reports",:name=>miq_report.name)
          @sb[:parent_reports] = nil  if !@sb[:saved_reports].blank?    # setting it to nil so saved reports can be displayed, unless all saved reports were deleted
        else
          add_flash(I18n.t("flash.report.selected_no_longer_exists", :typ=>"Chargeback"), :warning)
          nodes_len = 1  # Force to show the parent node
          self.x_node = nodes[0]
          @temp[:saved_reports] = nil
          cb_rpts_build_tree # Rebuild tree
        end
      end
    end
  end

  def cb_rpt_build_folder_nodes
    @temp[:parent_reports] = Hash.new
    srs = MiqReportResult.all(:conditions=>["db=? AND userid=? AND report_source!=?",
                                            "Chargeback",
                                            session[:userid],
                                            "Generated by user"],
                              :select => "miq_report_id, name",
                              :group=>"miq_report_id, name")
    srs.sort{|a,b| a.name.downcase <=> b.name.downcase}.each_with_index do |sr, sr_idx|
      @temp[:parent_reports][sr.name] = "#{to_cid(sr.miq_report_id)}-#{sr_idx}"
    end
  end

  def cb_rpts_get_all_reps(nodeid)
    @sb[:miq_report_id] = from_cid(nodeid)
    miq_report = MiqReport.find(@sb[:miq_report_id])
    saved_reports = MiqReportResult.all(:conditions=> ["miq_report_id = ? and userid = ?", @sb[:miq_report_id], session[:userid]], :order => "created_on DESC", :select => "id, miq_report_id, name,last_run_on,report_source")
    @sb[:last_run_on] = Hash.new
    @sb[:timezone_abbr] = @timezone_abbr if @timezone_abbr  #Saving converted time to be displayed on saved reports list view
    saved_reports.each do |s|
      @sb[:last_run_on][s.last_run_on] = "#{convert_time_from_utc(s.last_run_on).strftime('%m/%d/%Y %I:%M')} #{@sb[:timezone_abbr]}"
    end
    @sb[:tree_typ] = "reports"
    @right_cell_text = I18n.t("cell_header.model_record",:model=>"Reports",:name=>miq_report.name)
    return saved_reports
  end

  def cb_rates_build_tree
    TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", @sb)
  end

  # Build a Catalog Items explorer tree
  def cb_assignments_build_tree
    TreeBuilderChargebackAssignments.new("cb_assignments_tree", "cb_assignments", @sb)
  end

  # Common Schedule button handler routines
  def process_cb_rates(rates, task)
    process_elements(rates, ChargebackRate, task)
  end

  # Set form variables for edit
  def cb_rate_set_form_vars
    @edit = Hash.new
    @edit[:rate] = @sb[:rate]
    @edit[:key] = "cbrate_edit__#{@sb[:rate].id || "new"}"
    @edit[:rate_details] = @sb[:rate_details]
    @edit[:new]     = HashWithIndifferentAccess.new
    @edit[:current] = HashWithIndifferentAccess.new
    @edit[:rec_id] = @sb[:rate].id || nil
    @in_a_form = true

    @edit[:new][:description] = @sb[:rate].description
    @edit[:new][:rate_type] = @sb[:rate].rate_type ? @sb[:rate].rate_type : x_node.split('-').last
    @edit[:new][:details] = Array.new

    @sb[:rate_details].each do |r|
      temp = Hash.new
      temp[:rate] = (!r.rate.nil? && r.rate != "") ? r.rate : 0
      temp[:per_time] = r.per_time ? r.per_time : "hourly"
      @edit[:new][:details].push(temp)
    end

    @edit[:new][:per_time_types] = {
      "hourly" => "Hourly",
      "daily" => "Daily",
      "weekly" => "Weekly",
      "monthly" => "Monthly"
    }
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  # Get variables from edit form
  def cb_rate_get_form_vars
    @sb[:rate] = @edit[:rate]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:details].each_with_index do |detail,i|
      @edit[:new][:details][i][:rate] = params["rate_#{i}".to_sym] if params["rate_#{i}".to_sym]
      @edit[:new][:details][i][:per_time] = params["per_time_#{i}".to_sym] if params["per_time_#{i}".to_sym]
    end
  end

  def cb_rate_set_record_vars
    @edit[:new][:details].each_with_index do |rate,i|
      @sb[:rate_details][i].rate               = @edit[:new][:details][i][:rate]
      @sb[:rate_details][i].per_time           = @edit[:new][:details][i][:per_time]
      @sb[:rate_details][i].chargeback_rate_id = @sb[:rate].id
    end
  end

  # Set record vars for save
  def cb_assign_set_record_vars
    if @edit[:new][:cbshow_typ].ends_with?("-tags")
      @edit[:set_assignments] = []
      @edit[:cb_assign][:tags].each do |id, tag|
        key = "#{@edit[:new][:cbshow_typ]}__#{id}"
        if !@edit[:new][key].nil? && @edit[:new][key] != "nil"
          temp = {
            :cb_rate => ChargebackRate.find(@edit[:new][key]),
            :tag     => [Classification.find_by_id(id)],
          }
          temp[:tag].push(@edit[:new][:cbshow_typ].split("-").first)
          @edit[:set_assignments].push(temp)
        end
      end
    else
      @edit[:set_assignments] = []
      @edit[:cb_assign][:cis].each do |id, ci|
        key = "#{@edit[:new][:cbshow_typ]}__#{id}"
        if !@edit[:new][key].nil? && @edit[:new][key] != "nil"
          temp = { :cb_rate => ChargebackRate.find(@edit[:new][key]) }
          model = if @edit[:new][:cbshow_typ] == "enterprise"
                    MiqEnterprise
                  else
                    Object.const_get(@edit[:new][:cbshow_typ].camelize) rescue nil
                  end

          temp[:object] = model.find_by_id(id) unless model.nil?
          @edit[:set_assignments].push(temp)
        end
      end
    end
  end

  # Set form variables for edit
  def cb_assign_set_form_vars
    @edit = {
      :cb_rates  => {},
      :cb_assign => {},
    }
    ChargebackRate.all.each do |cbr|
      if cbr.rate_type == x_node.split('-').last
        @edit[:cb_rates][cbr.id.to_s] = cbr.description
      end
    end
    @edit[:key] = "cbassign_edit__#{x_node}"
    @edit[:new]     = HashWithIndifferentAccess.new
    @edit[:current] = HashWithIndifferentAccess.new
    @edit[:current_assignment] = ChargebackRate.get_assignments(x_node.split('-').last)
    unless @edit[:current_assignment].empty?
      @edit[:new][:cbshow_typ] =  case @edit[:current_assignment][0][:object]
                                  when EmsCluster
                                    "ems_cluster"
                                  when ExtManagementSystem
                                    "ext_management_system"
                                  when MiqEnterprise
                                    "enterprise"
                                  when NilClass
                                    "#{@edit[:current_assignment][0][:tag][1]}-tags"
                                  else
                                    @edit[:current_assignment][0][:object].class.name.downcase
                                  end
    end
    if @edit[:new][:cbshow_typ] && @edit[:new][:cbshow_typ].ends_with?("-tags")
      get_categories_all
      tag = @edit[:current_assignment][0][:tag][0]
      if tag
        @edit[:new][:cbtag_cat] = tag["parent_id"].to_s
        get_tags_all(tag["parent_id"])
      else
        @edit[:current_assignment] = []
      end
    elsif @edit[:new][:cbshow_typ]
      get_cis_all
    end
    if @edit[:new][:cbshow_typ] && @edit[:new][:cbshow_typ].ends_with?("-tags") && @edit[:cb_assign][:tags]
      @edit[:current_assignment].each do |el|
        if el[:object]
          @edit[:new]["#{@edit[:new][:cbshow_typ]}__#{el[:object]["id"]}"] = el[:cb_rate]["id"].to_s
        elsif el[:tag]
          @edit[:new]["#{@edit[:new][:cbshow_typ]}__#{el[:tag][0]["id"]}"] = el[:cb_rate]["id"].to_s
        end
      end
    else
      @edit[:current_assignment].each do |el|
        if el[:object]
          @edit[:new]["#{@edit[:new][:cbshow_typ]}__#{el[:object]["id"]}"] = el[:cb_rate]["id"].to_s
        elsif el[:tag]
          @edit[:new]["#{@edit[:new][:cbshow_typ]}__#{el[:tag][0]["id"]}"] = el[:cb_rate]["id"].to_s
        end
      end
    end
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
    @in_a_form = true
  end

  def get_categories_all
    @edit[:cb_assign][:cats] = Hash.new
    Classification.categories.collect { |c| c if !c.read_only? && c.show && c.entries.size > 0 }.compact.each{|c|@edit[:cb_assign][:cats][c.id.to_s] = c.description}
  end

  def get_tags_all(category)
    @edit[:cb_assign][:tags] = Hash.new
    classification = Classification.find_by_id(category.to_s)
    classification.entries.each { |e| @edit[:cb_assign][:tags][e.id.to_s] = e.description } if classification
  end

  def get_cis_all
    @edit[:cb_assign][:cis] = Hash.new
    if @edit[:new][:cbshow_typ] == "enterprise"
      e_id = MiqEnterprise.first
      @edit[:cb_assign][:cis]["#{e_id.id}"] = "Enterprise"
    elsif @edit[:new][:cbshow_typ] == "storage"
      Storage.all.each do |s|
        @edit[:cb_assign][:cis][s.id] = s.name
      end
    elsif @edit[:new][:cbshow_typ] == "ext_management_system"
      ExtManagementSystem.all.each do |ms|
        @edit[:cb_assign][:cis][ms.id] = ms.name
      end
    elsif @edit[:new][:cbshow_typ] == "ems_cluster"
      EmsCluster.all.each do |cl|
        @edit[:cb_assign][:cis][cl.id] = cl.name
      end
    end
  end

  def cb_assign_params_to_edit(cb_assign_key)
    return unless @edit[:cb_assign][cb_assign_key]

    @edit[:cb_assign][cb_assign_key].each do |id, ci|
      key = "#{@edit[:new][:cbshow_typ]}__#{id}"
      @edit[:new][key] = params[key].to_s if params[key]
    end
  end

  # Get variables from edit form
  def cb_assign_get_form_vars
    @edit[:new][:cbshow_typ] = params[:cbshow_typ] if params[:cbshow_typ]
    @edit[:new][:cbtag_cat] = nil if params[:cbshow_typ]                  # Reset categories pull down if assign to selection is changed
    @edit[:new][:cbtag_cat] = params[:cbtag_cat].to_s if params[:cbtag_cat]

    if @edit[:new][:cbshow_typ].ends_with?("-tags")
      get_categories_all
      get_tags_all(params[:cbtag_cat]) if params[:cbtag_cat]
    else
      get_cis_all
    end

    cb_assign_params_to_edit(:cis)
    cb_assign_params_to_edit(:tags)
  end

  def replace_right_cell(replace_trees = [])
    replace_trees = @replace_trees if @replace_trees  # get_node_info might set this
    @explorer = true
    chargeback_tree = cb_rates_build_tree if replace_trees.include?(:cb_rates)
    c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename)

    # Build a presenter to render the JS
    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
      :temp        => @temp
    )
    r = proc { |opts| render_to_string(opts) }

    replace_trees.each do |tree|
      case tree
      when :cb_rates
        presenter[:replace_partials][:cb_rates_tree_div]   = r[
            :partial => 'shared/tree',
            :locals  => {:tree => chargeback_tree,
                         :name => chargeback_tree.name.to_s
            }
        ]
      end
    end

    # FIXME
    #  if params[:action].ends_with?("_delete")
    #    page << "cfmeDynatree_activateNodeSilently('#{x_active_tree.to_s}', '<%= x_node %>');"
    #  end
    #presenter[:select_node] = x_node if params[:action].ends_with?("_delete")
    presenter[:osf_node] = x_node

    case x_active_tree
    when :cb_rates_tree
      # Rates accordion
      if c_buttons && c_xml
        presenter[:set_visible_elements][:center_buttons_div] = true
        presenter[:reload_toolbars][:center] = {:buttons => c_buttons, :xml => c_xml}
      end
      presenter[:expand_collapse_cells][:a] = c_buttons ? 'expand' : 'collapse'
      presenter[:update_partials][:main_div]   = r[:partial => 'rates_tabs']
      presenter[:update_partials][:paging_div] = r[:partial => 'layouts/x_pagingcontrols']
    when :cb_assignments_tree
      # Assignments accordion
      presenter[:update_partials][:main_div] = r[:partial => "assignments_tabs"]
    when :cb_reports_tree
      if c_buttons && c_xml
        presenter[:set_visible_elements][:center_buttons_div] = true
        presenter[:reload_toolbars][:center] = {:buttons => c_buttons, :xml => c_xml}
        presenter[:expand_collapse_cells][:a] = 'expand'
      else
        presenter[:set_visible_elements][:center_buttons_div] = false
        presenter[:expand_collapse_cells][:a] = 'collapse'
      end
      presenter[:update_partials][:main_div] = r[:partial => 'reports_list']
    end

    if @record || @in_a_form ||
        (@pages && (@items_per_page == ONE_MILLION || @pages[:items] == 0))
      if ["chargeback_rates_copy", "chargeback_rates_edit", "chargeback_rates_new"].include?(@sb[:action]) ||
          (x_active_tree == :cb_assignments_tree && ["Compute", "Storage"].include?(x_node.split('-').last))
        presenter[:expand_collapse_cells][:a] = 'collapse'
        presenter[:expand_collapse_cells][:c] = 'expand' # incase it was collapsed for summary screen, and incase there were no records on show_list
        presenter[:set_visible_elements][:form_buttons_div] = true
        presenter[:set_visible_elements][:pc_div_1] = false
        locals = {:record_id => @edit[:rec_id]}
        if x_active_tree == :cb_rates_tree
          locals[:action_url] = 'cb_rate_edit'
        else
          locals.update(
            :action_url   => 'cb_assign_update',
            :no_cancel    => true,
            :multi_record => true,
          )
        end
        presenter[:update_partials][:form_buttons_div] = r[:partial => 'layouts/x_edit_buttons', :locals => locals]
      else
        # Added so buttons can be turned off even tho div is not being displayed it still pops up Abandon changes box when trying to change a node on tree after saving a record
        presenter[:set_visible_elements][:buttons_on] = false
        presenter[:expand_collapse_cells][:a] = 'expand'
        presenter[:expand_collapse_cells][:c] = 'collapse'
      end
    else
      presenter[:set_visible_elements][:form_buttons_div] = false
      presenter[:set_visible_elements][:pc_div_1] = true
      if (x_active_tree == :cb_assignments_tree && x_node == "root") ||
         (x_active_tree == :cb_reports_tree     && !@report) ||
         (x_active_tree == :cb_rates_tree       && x_node == "root")
        presenter[:expand_collapse_cells][:a] = 'collapse'
        presenter[:set_visible_elements][:pc_div_1] = false
      end
      presenter[:expand_collapse_cells][:c] = 'expand'
    end

    presenter[:miq_record_id] = @record && !@in_a_form ? @record.id : @edit && @edit[:rec_id] && @in_a_form ? @edit[:rec_id] : nil

    ## Clear the JS gtl_list_grid var if changing to a type other than list
    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'
    presenter[:right_cell_text]     = @right_cell_text
    unless x_active_tree == :cb_assignments_tree
      presenter[:lock_unlock_trees][x_active_tree] = @in_a_form && @edit
    end
    render :js => presenter.to_html
  end

  def get_session_data
    @title        = "Chargeback"
    @layout     ||= "chargeback"
    @lastaction   = session[:chargeback_lastaction]
    @display      = session[:chargeback_display]
    @current_page = session[:chargeback_current_page]
  end

  def set_session_data
    session[:chargeback_lastaction]   = @lastaction
    session[:chargeback_current_page] = @current_page
    session[:chageback_display]       = @display unless @display.nil?
  end

end
