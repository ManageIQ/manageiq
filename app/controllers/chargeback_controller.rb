class ChargebackController < ApplicationController
  @@fixture_dir = File.join(Rails.root, "db/fixtures")

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  # FIXME: -- is INDEX needed ?
  def index
    redirect_to :action => 'explorer'
  end

  def x_button
    @sb[:action] = params[:pressed]
    @_params[:typ] = params[:pressed].split('_').last
    cb_rate_edit if ["chargeback_rates_copy", "chargeback_rates_edit", "chargeback_rates_new"].include?(params[:pressed])
    cb_rates_delete if params[:pressed] == "chargeback_rates_delete"
  end

  def x_show
    @explorer = true
    if x_active_tree == :cb_rates_tree
      @record = identify_record(params[:id], ChargebackRate)
      nodeid = x_build_node_id(@record)
      params[:id] = "xx-#{@record.rate_type}_#{nodeid}"
      params[:tree] = x_active_tree.to_s
      tree_select
    end
  end

  def accordion_select
    self.x_active_accord = params[:id].sub(/_accord$/, '')
    self.x_active_tree   = "#{x_active_accord}_tree"
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
    build_accordions_and_trees

    @sb[:open_tree_nodes] ||= []

    @right_cell_text = case x_active_tree
                       when :cb_rates_tree       then _("All %{models}") % {:models => ui_lookup(:models => "ChargebackRate")}
                       when :cb_assignments_tree then _("All Assignments")
                       when :cb_reports_tree     then _("All Saved Chargeback Reports")
                       end
    set_form_locals
    session[:changed] = false

    render :layout => "application" unless request.xml_http_request?
  end

  def set_form_locals
    if x_active_tree == :cb_rates_tree
      @x_edit_buttons_locals = {:action_url => 'cb_rate_edit'}
    elsif x_active_tree == :cb_assignments_tree
      @x_edit_buttons_locals = {
        :action_url   => 'cb_assign_update',
        :no_cancel    => true,
        :multi_record => true
      }
    end
  end

  # Show the main Schedules list view
  def cb_rates_list
    @listicon = "chargeback_rates"
    @gtl_type = "list"
    @ajax_paging_buttons = true
    @explorer = true
    if params[:ppsetting]                                              # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                        # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page          # Set the per page setting for this gtl type
    end
    @sortcol = session[:rates_sortcol].nil? ? 0 : session[:rates_sortcol].to_i
    @sortdir = session[:rates_sortdir].nil? ? "ASC" : session[:rates_sortdir]

    @view, @pages = get_view(ChargebackRate, :conditions => ["rate_type=?", x_node.split('-').last])  # Get the records (into a view) and the paginator

    @current_page = @pages[:current] unless @pages.nil?  # save the current page number
    session[:rates_sortcol] = @sortcol
    session[:rates_sortdir] = @sortdir

    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page]
      render :update do |page|                    # Use RJS to update the display
        page.replace("gtl_div", :partial => "layouts/x_gtl", :locals => {:action_url => "cb_rates_list"})
        page.replace_html("paging_div", :partial => "layouts/x_pagingcontrols")
        page << "miqSparkle(false)"
      end
    end
  end

  def cb_rate_edit
    assert_privileges(params[:pressed]) if params[:pressed]
    case params[:button]
    when "cancel"
      add_flash("#{!@sb[:rate] || @sb[:rate].id.blank? ? _("Add of new %{model} was cancelled by the user") %
          {:model => ui_lookup(:model => "ChargebackRate")} :
        _("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => "ChargebackRate"), :name => @sb[:rate].description}}")
      get_node_info(x_node)
      @sb[:rate] = @sb[:rate_details] = @sb[:num_tiers] = nil
      @edit = session[:edit] = nil  # clean out the saved info
      session[:changed] =  false
      replace_right_cell
    when "save", "add"
      id = params[:id] && params[:button] == "save" ? params[:id] : "new"
      return unless load_edit("cbrate_edit__#{id}", "replace_cell__chargeback")
      @sb[:rate] = @edit[:rate] if @edit && @edit[:rate]
      if @edit[:new][:description].nil? || @edit[:new][:description] == ""
        add_flash(_("Description is required"), :error)
        @sb[:rate] = @sb[:rate_details] = @sb[:tiers] = nil
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
        return
      end
      @sb[:rate].description = @edit[:new][:description]
      @sb[:rate].rate_type = @edit[:new][:rate_type] if @edit[:new][:rate_type]
      if params[:button] == "add"
        cb_rate_set_record_vars
        @sb[:rate].chargeback_rate_details.replace(@sb[:rate_details])
        @sb[:rate].chargeback_rate_details.each_with_index do |detail, i|
          detail.chargeback_tiers.replace(@sb[:tiers][i])
        end

        if @sb[:rate].save
          AuditEvent.success(build_saved_audit(@sb[:rate], @edit))
          add_flash(_("%{model} \"%{name}\" was added") % {:model => ui_lookup(:model => "ChargebackRate"), :name => @sb[:rate].description})
          @edit = session[:edit] = nil  # clean out the saved info
          session[:changed] =  @changed = false
          get_node_info(x_node)
          @sb[:rate] = @sb[:rate_details] = @sb[:tiers] = nil
          replace_right_cell([:cb_rates])
        else
          @sb[:rate].errors.each do |field, msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          @sb[:rate_details].each do |detail|
            detail.errors.each { |field, msg| add_flash("'#{detail.description}' #{field.to_s.capitalize} #{msg}", :error) }
            detail.chargeback_tiers.each do |tier|
              tier.errors.each do |field, msg|
                 add_flash("'#{detail.description}' #{field.to_s.capitalize} #{msg}", :error)
              end
            end
          end
          @changed = session[:changed] = (@edit[:new] != @edit[:current])
          @sb[:rate] = @sb[:rate_details] = @sb[:tiers] = nil
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
        end
      else      # for save button
        cb_rate_set_record_vars

        # Detect errors saving tiers
        tiers_valid = @sb[:tiers].all? { |tiers| tiers.all?(&:valid?) }

        # Replace the tiers
        if tiers_valid
          @sb[:rate].chargeback_rate_details.each_with_index do |_detail, i|
            @sb[:rate_details][i].chargeback_tiers = @sb[:tiers][i]
          end
        end
        # Detect errors saving rate details
        rate_details_valid = @sb[:rate_details].all?(&:valid?)

        if rate_details_valid && tiers_valid && @sb[:rate].save
          @sb[:rate_details].each(&:save)
          @sb[:rate].chargeback_rate_details.each { |detail| detail.chargeback_tiers = [] } # Clear the chargeback tiers
          @sb[:tiers].each { |tiers| tiers.each(&:save) } # Save tiers
          AuditEvent.success(build_saved_audit(@sb[:rate], @edit))
          add_flash(_("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:model => "ChargebackRate"), :name => @sb[:rate].description})
          @edit = session[:edit] = nil  # clean out the saved info
          @changed = false
          get_node_info(x_node)
          @sb[:rate] = @sb[:rate_details] = @sb[:tiers] = nil
          replace_right_cell([:cb_rates])
        else
          @sb[:rate].errors.each do |field, msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          @sb[:rate_details].each do |detail|
            display_detail_errors(detail, detail.errors)
          end
          @sb[:tiers].each_with_index do |tiers, detail_index|
            tiers.each do |tier|
              display_detail_errors(@sb[:rate_details][detail_index], tier.errors)
            end
          end
          @changed = session[:changed] = (@edit[:new] != @edit[:current])
          @sb[:rate] = @sb[:rate_details] = @sb[:tiers] = nil
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
        @sb[:rate_details] = []
        @sb[:num_tiers] = []
        @sb[:tiers] = []
        rate = ChargebackRate.find(obj[0])
        @sb[:rate] = ChargebackRate.new
        @sb[:rate].description = _("Copy of %{description}") % {:description => rate.description}
        @sb[:rate].rate_type = rate.rate_type
        rate_details = rate.chargeback_rate_details.to_a
        rate_details.sort_by! { |rd| [rd.group.downcase, rd.description.downcase] }
        # Create new rate detail records for copied rate record
        rate_details.each_with_index do |detail, detail_index|
          @sb[:tiers][detail_index] = []
          detail_copy = ChargebackRateDetail.new(:description                        => detail[:description],
                                                 :source                             => detail[:source],
                                                 :per_time                           => detail[:per_time],
                                                 :group                              => detail[:group],
                                                 :per_unit                           => detail[:per_unit],
                                                 :metric                             => detail[:metric],
                                                 :chargeback_rate_detail_measure_id  => detail[:chargeback_rate_detail_measure_id],
                                                 :chargeback_rate_detail_currency_id => detail[:chargeback_rate_detail_currency_id])
          detail.chargeback_tiers.each do |tier|
            tier_copy = ChargebackTier.new(:start                     => tier[:start],
                                           :end                       => tier[:end],
                                           :fixed_rate                => tier[:fixed_rate],
                                           :variable_rate             => tier[:variable_rate],
                                           :chargeback_rate_detail_id => detail_copy.id)
            @sb[:tiers][detail_index].push(tier_copy)
          end
          @sb[:rate_details].push(detail_copy) unless @sb[:rate_details].include?(detail_copy)
          @sb[:num_tiers][detail_index] = @sb[:tiers][detail_index].size
        end
      else
        session[:changed] = false
        @sb[:rate] = params[:typ] == "new" ? ChargebackRate.new : ChargebackRate.find(obj[0])
        @sb[:num_tiers] = []
        @sb[:tiers] = []
        @sb[:rate_details] = @sb[:rate].chargeback_rate_details.to_a
        @sb[:rate_details].sort_by! { |rd| [rd[:group].downcase, rd[:description].downcase] }
        @sb[:rate_details].each_with_index do |detail, i|
          @sb[:tiers][i] = detail.chargeback_tiers.to_a
          @sb[:num_tiers][i] = detail.chargeback_tiers.to_a.length
        end
        if @sb[:rate_details].blank?
          fixture_file = File.join(@@fixture_dir, "chargeback_rates.yml")
          if File.exist?(fixture_file)
            fixture = YAML.load_file(fixture_file)
            fixture.each do |cbr|
              if cbr[:rate_type] == x_node.split('-').last
                rates = cbr.delete(:rates)
                rates.each_with_index do |detail, detail_index|
                  detail_new = ChargebackRateDetail.new(:description => detail[:description],
                                                        :source      => detail[:source],
                                                        :per_time    => detail[:per_time],
                                                        :group       => detail[:group],
                                                        :per_unit    => detail[:per_unit],
                                                        :metric      => detail[:metric])
                  @sb[:tiers][detail_index] = []
                  tiers = detail.delete(:tiers)
                  rate_tiers = []
                  tiers.each do |tier|
                    tier_new = ChargebackTier.new(:start                     => tier.delete(:start),
                                                  :end                       => tier.delete(:end),
                                                  :fixed_rate                => tier.delete(:fixed_rate),
                                                  :variable_rate             => tier.delete(:variable_rate),
                                                  :chargeback_rate_detail_id => detail_new.id)
                    rate_tiers.append(tier_new)
                  end
                  # if the rate detail has a measure associated
                  unless detail[:measure].nil?
                    # Copy the measure id of the rate_detail linkig with the rate_detail_measure
                    id_measure = ChargebackRateDetailMeasure.find_by(:name => detail[:measure]).id
                    detail_new.chargeback_rate_detail_measure_id = id_measure
                  end
                  # Copy the currency id of the rate detail linking with the rate_detail_currency
                  if detail[:type_currency]
                    id_currency = ChargebackRateDetailCurrency.find_by(:name => detail[:type_currency]).id
                    detail_new.chargeback_rate_detail_currency_id = id_currency
                  end
                  @sb[:rate_details].push(detail_new) unless @sb[:rate_details].include?(detail_new)
                  @sb[:tiers][detail_index] = rate_tiers
                end
              end
            end
          end
        end
      end
      cb_rate_set_form_vars
      @in_a_form = true
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def cb_rate_form_field_changed
    return unless load_edit("cbrate_edit__#{params[:id]}", "replace_cell__chargeback")
    cb_rate_get_form_vars
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      # Update the new column with the code of the currency selected by the user
      first_new_detail = @edit[:new][:details].first
      new_rate_detail_currency = ChargebackRateDetailCurrency.find_by(:id => first_new_detail[:currency])
      @edit[:new][:details].each_with_index do |_detail, i|
        new_rate_details = @edit[:new][:details][i]
        current_rate_details = @edit[:current][:details][i]
        next if new_rate_details[:currency] == current_rate_details[:currency]

        current_rate_details[:currency] = new_rate_details[:currency]
        params[:code_currency] = new_rate_detail_currency.code
        params[:id_column] = i
        params[:num_tiers] = @sb[:num_tiers][i]
        page.replace("column_currency_#{i}", :partial => "cb_new_currency_column")
      end
      page << javascript_for_miq_button_visibility(changed)
    end
    cb_rate_get_form_vars
  end

  def cb_rate_show
    @display = "main"
    @sb[:selected_rate_details] = @record.chargeback_rate_details.to_a
    @sb[:selected_rate_details].sort_by! { |rd| [rd[:group].downcase, rd[:description].downcase] }
    if @record.nil?
      redirect_to :action => "cb_rates_list", :flash_msg => _("Error: Record no longer exists in the database"), :flash_error => true
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
        add_flash(_("No %{records} were selected for deletion") %
          {:records => ui_lookup(:models => "ChargebackRate")}, :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      end
      process_cb_rates(rates, "destroy")  unless rates.empty?
      if flash_errors? && @flash_array.count == 1
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      else
        cb_rates_list
        @right_cell_text = _("%{typ} %{model}") % {:typ => x_node.split('-').last,
                           :model => ui_lookup(:models => "ChargebackRate")}
        replace_right_cell([:cb_rates])
      end
    else # showing 1 rate, delete it
      if params[:id].nil? || ChargebackRate.find_by_id(params[:id]).nil?
        add_flash(_("%{record} no longer exists") % {:record => ui_lookup(:model => "ChargebackRate")}, :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      else
        rates.push(params[:id])
      end
      cb_rate = ChargebackRate.find_by_id(params[:id])
      process_cb_rates(rates, "destroy")  unless rates.empty?
      self.x_node = "xx-#{cb_rate.rate_type}"
      if flash_errors?
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      else
        cb_rates_list
        @right_cell_text = _("%{typ} %{model}") % {:typ => x_node.split('-').last,
                           :model => ui_lookup(:models => "ChargebackRate")}
        replace_right_cell([:cb_rates])
      end
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def cb_assign_field_changed
    return unless load_edit("cbassign_edit__#{x_node}", "replace_cell__chargeback")
    cb_assign_get_form_vars
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      page.replace("cb_assignment_div", :partial => "cb_assignments") if params[:cbshow_typ] || params[:cbtag_cat]      # only replace if cbshow_typ or cbtag_cat has changed
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  # Add a new tier at the end
  def cb_tier_add
    @edit = session[:edit]
    detail_index = params[:detail_index]
    ii = detail_index.to_i
    @sb[:num_tiers][ii] =
      @edit[:new][:details][ii][:chargeback_tiers].to_a.length if @edit[:new][:details][ii][:chargeback_tiers]
    @sb[:num_tiers][ii] = 1 unless @sb[:num_tiers][ii] || @sb[:num_tiers][ii] == 0
    @sb[:num_tiers][ii] += 1
    tier_index = @sb[:num_tiers][ii] - 1
    @edit[:new][:tiers][ii][tier_index] = {}
    @edit[:new][:tiers][ii][tier_index][:start] = @edit[:new][:tiers][ii][tier_index - 1][:end]
    @edit[:new][:tiers][ii][tier_index][:end] = Float::INFINITY
    @edit[:new][:tiers][ii][tier_index][:fixed_rate] = 0.0
    @edit[:new][:tiers][ii][tier_index][:variable_rate] = 0.0
    params[:code_currency] = ChargebackRateDetailCurrency.find_by(:id => @edit[:new][:details][ii][:currency]).code
    add_row(detail_index, tier_index - 1)
  end

  # Remove the selected tier
  def cb_tier_remove
    @edit = session[:edit]
    index = params[:index]
    detail_index, tier_to_remove_index = index.split("-")
    params[:detail_index] = detail_index
    detail_index = detail_index.to_i
    tier_to_remove_index = tier_to_remove_index.to_i
    @sb[:num_tiers][detail_index] = @sb[:num_tiers][detail_index] - 1
    tiers = @edit[:new][:tiers][detail_index]
    @edit[:new][:tiers][detail_index].each_with_index do |_tier, tier_index|
      next if tier_index <= tier_to_remove_index
      @edit[:new][:tiers][detail_index][tier_index - 1] = @edit[:new][:tiers][detail_index][tier_index]
    end
    replace_rows(detail_index, tiers, tier_to_remove_index) # Replace tiers in the view
    # Delete tier records
    @edit[:new][:tiers][detail_index].delete_at(@sb[:num_tiers][detail_index])
    @sb[:tiers][detail_index].delete_at(@sb[:num_tiers][detail_index])
  end

  def cb_assign_update
    if params[:button] == "reset"
      get_node_info(x_node)
      add_flash(_("All changes have been reset"), :warning)
      replace_right_cell
    else
      return unless load_edit("cbassign_edit__#{x_node}", "replace_cell__chargeback")
      cb_assign_set_record_vars
      rate_type = x_node.split('-').last
      begin
        ChargebackRate.set_assignments(rate_type, @edit[:set_assignments])
      rescue StandardError => bang
        add_flash(_("Error during 'Rate assignments': %{error_message}") % {:error_message => bang.message}, :error)
        render :update do |page|                    # Use RJS to update the display
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      else
        add_flash(_("Rate Assignments saved"))
        get_node_info(x_node)
        replace_right_cell
      end
    end
  end

  private ############################

  def features
    [{:role  => "chargeback_reports",
      :name  => :cb_reports,
      :title => _("Reports")},

     {:role  => "chargeback_rates",
      :name  => :cb_rates,
      :title => _("Rates")},

     {:role  => "chargeback_assignments",
      :name  => :cb_assignments,
      :title => _("Assignments")},
    ].map do |hsh|
      ApplicationController::Feature.new_with_hash(hsh)
    end
  end

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
    @right_cell_text ||= _("Saved Chargeback Report [%{name}]") % {:name => rr.name}
    if rr.userid != session[:userid]
      add_flash(_("Report is not authorized for the logged in user"), :error)
      @saved_reports = cb_rpts_get_all_reps(id.split('-')[1])
      return
    else
      @report_result_id = session[:report_result_id] = rr.id
      session[:report_result_runtime]  = rr.last_run_on
      @report = rr.report_results
      session[:rpt_task_id] = nil
      if @report.blank?
        add_flash(_("Saved Report \"%{name}\" not found, Schedule may have failed") %
          {:name => format_timezone(rr.last_run_on, Time.zone, "gtl")}, :error)
        @saved_reports = cb_rpts_get_all_reps(rr.miq_report_id.to_s)
        rep = MiqReport.find_by_id(rr.miq_report_id)
        if x_active_tree == :cb_reports
          self.x_node = "reports-#{rep.id}"
        else
          @sb[:rpt_menu].each_with_index do |lvl1, i|
            if lvl1[0] == current_tenant.name
              lvl1[1].each_with_index do |lvl2, k|
                if lvl2[0].downcase == "custom"
                  @sb[:active_node]["report"] = "reports-#{i}-#{k}-#{lvl2[1].length - 1}_#{rep.id}"
                end
              end
            end
          end
        end
        return
      else
        if @report.contains_records?
          @html = report_first_page(rr)              # Get the first page of the results
          unless @report.graph.blank?
            @zgraph = true
            @ght_type = "hybrid"
          else
            @ght_type = "tabular"
          end
          @report.extras ||= {}                # Create extras hash
          @report.extras[:to_html] ||= @html        # Save the html report
        else
          add_flash(_("No records found for this report"), :warning)
        end
      end
    end
  end

  def get_node_info(node)
    node = valid_active_node(node)
    if x_active_tree == :cb_rates_tree
      if node == "root"
        @sb[:rate] = @record = @sb[:selected_rate_details] = nil
        @right_cell_text = _("All %{models}") % {:models => ui_lookup(:models => "ChargebackRate")}
      elsif ["xx-Compute", "xx-Storage"].include?(node)
        @sb[:rate] = @record = @sb[:selected_rate_details] = nil
        @right_cell_text = _("%{typ} %{model}") % {:typ => x_node.split('-').last, :model => ui_lookup(:models => "ChargebackRate")}
        cb_rates_list
      else
        @record = ChargebackRate.find(from_cid(node.split('_').last.split('-').last))
        @sb[:action] = nil
        @right_cell_text = _("%{typ} %{model} \"%{name}\"") % {:typ => @record.rate_type, :model => ui_lookup(:model => "ChargebackRate"), :name => @record.description}
        cb_rate_show
      end
    elsif x_active_tree == :cb_assignments_tree
      if ["xx-Compute", "xx-Storage"].include?(node)
        cb_assign_set_form_vars
        @right_cell_text = _("%{typ} %{model}") % {:typ => node.split('-').last, :model => "Rate Assignments"}
      else
        @right_cell_text = _("All Assignments")
      end
    elsif x_active_tree == :cb_reports_tree
      @nodetype = node.split("-")[0]
      nodes = x_node.split('_')
      nodes_len = nodes.length

      # On the root node
      if x_node == "root"
        cb_rpt_build_folder_nodes
        @right_cell_div = "reports_list_div"
        @right_cell_text = _("All %s") % "Saved Chargeback Reports"
      elsif nodes_len == 2
        # On a saved report node
        cb_rpts_show_saved_report
        if @report
          s = MiqReportResult.find_by_id(from_cid(nodes.last.split('-').last))
          @right_cell_div = "reports_list_div"
          @right_cell_text = _("%{model} \"%{name}\"") % {:model => "Saved Chargeback Report", :name => format_timezone(s.last_run_on, Time.zone, "gtl")}
        else
          add_flash(_("Selected Saved Chargeback Report no longer exists"), :warning)
          self.x_node = nodes[0..1].join("_")
          cb_rpts_build_tree # Rebuild tree
        end
      # On a saved reports parent node
      else
        # saved reports under report node on saved report accordion
        @saved_reports = cb_rpts_get_all_reps(nodes[0].split('-')[1])
        unless @saved_reports.empty?
          @sb[:sel_saved_rep_id] = nodes[1]
          @right_cell_div = "reports_list_div"
          miq_report = MiqReport.find(@sb[:miq_report_id])
          @right_cell_text = _("%{model} \"%{name}\"") % {:model => "Saved Chargeback Reports", :name => miq_report.name}
          @sb[:parent_reports] = nil  unless @sb[:saved_reports].blank?    # setting it to nil so saved reports can be displayed, unless all saved reports were deleted
        else
          add_flash(_("Selected Chargeback Report no longer exists"), :warning)
          self.x_node = nodes[0]
          @saved_reports = nil
          cb_rpts_build_tree # Rebuild tree
        end
      end
    end
  end

  def cb_rpt_build_folder_nodes
    @parent_reports = {}

    MiqReportResult.auto_generated.select(:miq_report_id, :name).distinct.where(
      :db     => "Chargeback",
      :userid => session[:userid]
    ).sort_by { |sr| sr.name.downcase }.each_with_index do |sr, sr_idx|
      @parent_reports[sr.name] = "#{to_cid(sr.miq_report_id)}-#{sr_idx}"
    end
  end

  def cb_rpts_get_all_reps(nodeid)
    @sb[:miq_report_id] = from_cid(nodeid)
    miq_report = MiqReport.find(@sb[:miq_report_id])
    saved_reports = miq_report.miq_report_results.where(:userid => session[:userid])
                    .select("id, miq_report_id, name,last_run_on,report_source").order("created_on DESC")
    @sb[:last_run_on] = {}
    @sb[:timezone_abbr] = @timezone_abbr if @timezone_abbr  # Saving converted time to be displayed on saved reports list view
    saved_reports.each do |s|
      @sb[:last_run_on][s.last_run_on] =
        "#{convert_time_from_utc(s.last_run_on).strftime('%m/%d/%Y %I:%M')} #{@sb[:timezone_abbr]}" if s.last_run_on
    end
    @sb[:tree_typ] = "reports"
    @right_cell_text = _("%{model} \"%{name}\"") % {:model => "Reports", :name => miq_report.name}
    saved_reports
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
    @edit = {}
    @edit[:rate] = @sb[:rate]
    @edit[:key] = "cbrate_edit__#{@sb[:rate].id || "new"}"
    @edit[:rate_details] = @sb[:rate_details]
    @edit[:new]     = HashWithIndifferentAccess.new
    @edit[:current] = HashWithIndifferentAccess.new
    @edit[:rec_id] = @sb[:rate].id || nil
    @in_a_form = true

    @edit[:new][:description] = @sb[:rate].description
    @edit[:new][:rate_type] = @sb[:rate].rate_type ? @sb[:rate].rate_type : x_node.split('-').last
    @edit[:new][:details] = []
    # Select the currency of the first chargeback_rate_detail. All the chargeback_rate_details have the same currency
    @edit[:new][:currency] = @sb[:rate_details][0].chargeback_rate_detail_currency_id
    @edit[:new][:tiers] = []

    @sb[:rate_details].each_with_index do |detail, detail_index|
      temp = {}
      temp = detail.slice(:per_time, :per_unit, :detail_measure)
      temp[:per_time] ||= "hourly"
      temp[:currency] = detail.detail_currency.id
      @edit[:new][:tiers][detail_index] = []
      @sb[:tiers][detail_index].each do |tier|
        temp2 = {}
        temp2 = tier.slice(:fixed_rate, :variable_rate, :start, :end)
        temp2[:chargeback_rate_detail_id] = detail.id
        @edit[:new][:tiers][detail_index].push(temp2)
      end
      @sb[:num_tiers][detail_index] = @sb[:tiers][detail_index].length
      @edit[:new][:details].push(temp)
    end

    @edit[:new][:per_time_types] = {
      "hourly"  => "Hourly",
      "daily"   => "Daily",
      "weekly"  => "Weekly",
      "monthly" => "Monthly"
    }
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  # Get variables from edit form
  def cb_rate_get_form_vars
    @sb[:rate] = @edit[:rate]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:details].each_with_index do |_detail, detail_index|
      _detail[:per_time] =
        params["per_time_#{detail_index}".to_sym] if params["per_time_#{detail_index}".to_sym]
      _detail[:per_unit] =
        params["per_unit_#{detail_index}".to_sym] if params["per_unit_#{detail_index}".to_sym]
      # Add currencies to chargeback_controller.rb
      _detail[:currency] = params[:currency] if params[:currency]

      # Save tiers into @edit
      (0..@sb[:num_tiers][detail_index].to_i - 1).each do |tier_index|
        @edit [:new][:tiers][detail_index][tier_index] = {} unless @edit[:new][:tiers][detail_index][tier_index]
        @edit[:new][:tiers][detail_index][tier_index][:fixed_rate] =
          params["fixed_rate_#{detail_index}_#{tier_index}".to_sym] if params["fixed_rate_#{detail_index}_#{tier_index}".to_sym]
        @edit[:new][:tiers][detail_index][tier_index][:variable_rate] =
          params["variable_rate_#{detail_index}_#{tier_index}".to_sym] if params["variable_rate_#{detail_index}_#{tier_index}".to_sym]
        @edit[:new][:tiers][detail_index][tier_index][:start] =
          params["start_#{detail_index}_#{tier_index}".to_sym] if params["start_#{detail_index}_#{tier_index}".to_sym]
        @edit[:new][:tiers][detail_index][tier_index][:end] =
          params["end_#{detail_index}_#{tier_index}".to_sym] if params["end_#{detail_index}_#{tier_index}".to_sym]
      end
    end
  end

  def cb_rate_set_record_vars
    @edit[:new][:details].each_with_index do |_detail, detail_index|
      @sb[:rate_details][detail_index].per_time           = _detail[:per_time]
      @sb[:rate_details][detail_index].per_unit           = _detail[:per_unit]
      # C: Record the currency selected in the edit view, in my chargeback_rate_details table
      @sb[:rate_details][detail_index].chargeback_rate_detail_currency_id = @edit[:new][:details][detail_index][:currency]
      @sb[:rate_details][detail_index].chargeback_rate_id = @sb[:rate].id
      # Save tiers into @sb
      @edit[:new][:tiers][detail_index].each_with_index do |_tier, tier_index|
        @sb[:tiers][detail_index][tier_index] =
          ChargebackTier.new(:start                     => _tier[:start],
                             :end                       => _tier[:end],
                             :fixed_rate                => _tier[:fixed_rate],
                             :variable_rate             => _tier[:variable_rate],
                             :chargeback_rate_detail_id => @sb[:rate_details][detail_index].id)
        if tier_index >= @sb[:num_tiers][detail_index]
          break
        end
      end
    end
  end

  # Set record vars for save
  def cb_assign_set_record_vars
    if @edit[:new][:cbshow_typ].ends_with?("-tags")
      @edit[:set_assignments] = []
      @edit[:cb_assign][:tags].each do |id, _tag|
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
      @edit[:cb_assign][:cis].each do |id, _ci|
        key = "#{@edit[:new][:cbshow_typ]}__#{id}"
        if !@edit[:new][key].nil? && @edit[:new][key] != "nil"
          temp = {:cb_rate => ChargebackRate.find(@edit[:new][key])}
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

    @edit[:current_assignment].each do |el|
      if el[:object]
        @edit[:new]["#{@edit[:new][:cbshow_typ]}__#{el[:object]["id"]}"] = el[:cb_rate]["id"].to_s
      elsif el[:tag]
        @edit[:new]["#{@edit[:new][:cbshow_typ]}__#{el[:tag][0]["id"]}"] = el[:cb_rate]["id"].to_s
      end
    end

    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
    @in_a_form = true
  end

  def get_categories_all
    @edit[:cb_assign][:cats] = {}
    Classification.categories.collect { |c| c if !c.read_only? && c.show && c.entries.size > 0 }.compact.each { |c| @edit[:cb_assign][:cats][c.id.to_s] = c.description }
  end

  def get_tags_all(category)
    @edit[:cb_assign][:tags] = {}
    classification = Classification.find_by_id(category.to_s)
    classification.entries.each { |e| @edit[:cb_assign][:tags][e.id.to_s] = e.description } if classification
  end

  WHITELIST_INSTANCE_TYPE = %w(enterprise storage ext_management_system ems_cluster tenant).freeze
  NOTHING_FORM_VALUE = "nil".freeze

  def get_cis_all
    @edit[:cb_assign][:cis] = {}
    klass = @edit[:new][:cbshow_typ]
    return if klass == NOTHING_FORM_VALUE || klass.nil? # no rate was selected
    unless WHITELIST_INSTANCE_TYPE.include?(klass)
      raise ArgumentError, "Received: #{klass}, expected one of #{WHITELIST_INSTANCE_TYPE}"
    end
    classtype =
      if klass == "enterprise"
        MiqEnterprise
      else
        klass.classify.constantize
      end
    classtype.all.each do |instance|
      @edit[:cb_assign][:cis][instance.id] = instance.name
    end
  end

  def cb_assign_params_to_edit(cb_assign_key)
    return unless @edit[:cb_assign][cb_assign_key]

    @edit[:cb_assign][cb_assign_key].each do |id, _ci|
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
    c_tb = build_toolbar(center_toolbar_filename)

    # Build a presenter to render the JS
    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
    )
    r = proc { |opts| render_to_string(opts) }
    replace_trees_by_presenter(presenter, :cb_rates => cb_rates_build_tree) if replace_trees.include?(:cb_rates)

    # FIXME
    #  if params[:action].ends_with?("_delete")
    #    page << "miqDynatreeActivateNodeSilently('#{x_active_tree.to_s}', '<%= x_node %>');"
    #  end
    # presenter[:select_node] = x_node if params[:action].ends_with?("_delete")
    presenter[:osf_node] = x_node

    case x_active_tree
    when :cb_rates_tree
      # Rates accordion
      if c_tb.present?
        presenter.reload_toolbars(:center => c_tb)
      end
      presenter.set_visibility(c_tb.present?, :toolbar)
      presenter.update(:main_div, r[:partial => 'rates_tabs'])
      presenter.update(:paging_div, r[:partial => 'layouts/x_pagingcontrols'])
    when :cb_assignments_tree
      # Assignments accordion
      presenter.update(:main_div, r[:partial => "assignments_tabs"])
    when :cb_reports_tree
      if c_tb.present?
        presenter.reload_toolbars(:center => c_tb)
        presenter.show(:toolbar)
      else
        presenter.hide(:toolbar)
      end
      presenter.update(:main_div, r[:partial => 'reports_list'])
      if @html
        presenter.update(:paging_div, r[:partial => 'layouts/saved_report_paging_bar',
                                        :locals  => @sb[:pages]])
        presenter.show(:paging_div)
      else
        presenter.hide(:paging_div)
      end
    end

    if @record || @in_a_form ||
       (@pages && (@items_per_page == ONE_MILLION || @pages[:items] == 0))
      if ["chargeback_rates_copy", "chargeback_rates_edit", "chargeback_rates_new"].include?(@sb[:action]) ||
         (x_active_tree == :cb_assignments_tree && ["Compute", "Storage"].include?(x_node.split('-').last))
        presenter.hide(:toolbar)
        # incase it was hidden for summary screen, and incase there were no records on show_list
        presenter.show(:paging_div, :form_buttons_div).hide(:pc_div_1)
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
        presenter.update(:form_buttons_div, r[:partial => 'layouts/x_edit_buttons', :locals => locals])
      else
        # Added so buttons can be turned off even tho div is not being displayed it still pops up Abandon changes box when trying to change a node on tree after saving a record
        presenter.hide(:buttons_on).show(:toolbar).hide(:paging_div)
      end
    else
      presenter.hide(:form_buttons_div).show(:pc_div_1)
      if (x_active_tree == :cb_assignments_tree && x_node == "root") ||
         (x_active_tree == :cb_reports_tree && !@report) ||
         (x_active_tree == :cb_rates_tree && x_node == "root")
        presenter.hide(:toolbar, :pc_div_1)
      end
      presenter.show(:paging_div)
    end

    presenter[:record_id] = determine_record_id_for_presenter

    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'

    presenter[:right_cell_text]     = @right_cell_text
    unless x_active_tree == :cb_assignments_tree
      presenter[:lock_unlock_trees][x_active_tree] = @in_a_form && @edit
    end
    render :js => presenter.to_html
  end

  def get_session_data
    @title        = _("Chargeback")
    @layout ||= "chargeback"
    @lastaction   = session[:chargeback_lastaction]
    @display      = session[:chargeback_display]
    @current_page = session[:chargeback_current_page]
  end

  def set_session_data
    session[:chargeback_lastaction]   = @lastaction
    session[:chargeback_current_page] = @current_page
    session[:chageback_display]       = @display unless @display.nil?
  end

  def display_detail_errors(detail, errors)
    errors.each { |field, msg| add_flash("'#{detail.description}' #{field.to_s.capitalize} #{msg}", :error) }
  end

  def add_row(i, pos)
    render :update do |page|
      # Update the first row to change the colspan
      page.replace("rate_detail_row_#{i}_0", :partial => "tier_first_row")
      # Insert the new tier after the last one
      page.insert_html(:after, "rate_detail_row_#{i}_#{pos}", :partial => "tier_row")
      page << javascript_for_miq_button_visibility(true)
    end
  end

  def replace_rows(detail_index, tiers, tier_to_remove_index)
    render :update do |page|
      page.replace("rate_detail_row_#{detail_index}_0", :partial => "tier_first_row")
      tiers.each_with_index do |_tier, tier_index|
        next if tier_index <= tier_to_remove_index
        # Move up tiers not to have blank rows
        # @edit[:new][:tiers][detail_index][tier_index - 1] = @edit[:new][:tiers][detail_index][tier_index]
        params[:tier_row] = tier_index
        page.replace("rate_detail_row_#{detail_index}_#{tier_index - 1}", :partial => "tier_row")
        params[:tier_row] = nil
      end
      # Delete the last row
      # delete_row(detail_index, @sb[:num_tiers][detail_index])
      page.replace("rate_detail_row_#{detail_index}_#{@sb[:num_tiers][detail_index]}", '')
      page << javascript_for_miq_button_visibility(true)
    end
  end
end
