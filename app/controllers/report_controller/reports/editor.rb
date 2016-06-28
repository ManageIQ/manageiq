module ReportController::Reports::Editor
  extend ActiveSupport::Concern

  CHARGEBACK_ALLOWED_FIELD_SUFFIXES = %w(_cost -owner_name _metric -provider_name -provider_uid -project_uid -archived).freeze

  def miq_report_new
    assert_privileges("miq_report_new")
    @_params.delete :id # incase add button was pressed from report show screen.
    miq_report_edit
  end

  def miq_report_copy
    assert_privileges("miq_report_copy")
    @report = nil     # Clear any saved report object
    if params[:tab] # Came in to change the tab
      check_tabs
      build_edit_screen
    else
      @sb[:miq_tab] = "edit_1"
      @rpt          = MiqReport.find(params[:id])
      @rpt.id       = nil # Treat as a new report
      set_form_vars
      build_edit_screen
    end
    @ina_form = @lock_tree = true
    replace_right_cell
  end

  def miq_report_edit
    assert_privileges("miq_report_edit")
    case params[:button]
    when "cancel"
      @edit[:rpt_id] ?
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => "MiqReport"), :name => @edit[:rpt_title]}) :
        add_flash(_("Add of new %{model} was cancelled by the user") % {:model => ui_lookup(:model => "MiqReport")})
      @edit = session[:edit] = nil # clean out the saved info
      replace_right_cell
    when "add", "save"
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("report_edit__#{id}", "replace_cell__explorer")
      get_form_vars
      @changed = (@edit[:new] != @edit[:current])
      @rpt = @edit[:rpt_id] ? find_by_id_filtered(MiqReport, params[:id]) :
          MiqReport.new
      set_record_vars(@rpt)
      unless valid_report?(@rpt)
        build_edit_screen
        replace_right_cell
        return
      end
      if @edit[:new][:graph_type] && (@edit[:new][:sortby1].blank? || @edit[:new][:sortby1] == NOTHING_STRING)
        add_flash(_("Report can not be saved unless sort field has been configured for Charts"), :error)
        @sb[:miq_tab] = "edit_4"
        build_edit_screen
        replace_right_cell
        return
      end
      if @rpt.save
        # update report name in menu if name is edited
        menu_repname_update(@edit[:current][:name], @edit[:new][:name]) if @edit[:current][:name] != @edit[:new][:name]
        AuditEvent.success(build_saved_audit(@rpt, @edit))
        @edit[:rpt_id] ?
          add_flash(_("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:model => "MiqReport"), :name => @rpt.name}) :
          add_flash(_("%{model} \"%{name}\" was added") % {:model => ui_lookup(:model => "MiqReport"), :name => @rpt.name})
        # only do this for new reports
        unless @edit[:rpt_id]
          self.x_node = "xx-#{@sb[:rpt_menu].length}_xx-#{@sb[:rpt_menu].length}-0"
          setnode_for_customreport
        end
        @edit = session[:edit] = nil # clean out the saved info
        if role_allows(:feature => "miq_report_widget_editor")
          # all widgets for this report
          get_all_widgets("report", from_cid(x_node.split('_').last))
        end
        replace_right_cell(:replace_trees => [:reports])
      else
        rpt.errors.each do |field, msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        @in_a_form = true
        session[:changed] = @changed ? true : false
        @changed = true
        replace_right_cell
      end
    else
      add_flash(_("All changes have been reset"), :warning) if params[:button] == "reset"
      @in_a_form = true
      @report = nil     # Clear any saved report object
      if params[:tab] # Came in to change the tab
        @rpt = @edit[:rpt_id] ? MiqReport.find(@edit[:rpt_id]) :
            MiqReport.new
        check_tabs
        build_edit_screen
      else
        @sb[:miq_tab] = "edit_1"
        @rpt = params[:id] && params[:id] != "new" ? MiqReport.find(params[:id]) :
                MiqReport.new
        if @rpt.rpt_type == "Default"
          flash = "Default reports can not be edited"
          redirect_to :action => "show", :id => @rpt.id, :flash_msg => flash, :flash_error => true
          return
        end
        set_form_vars
        build_edit_screen
      end
      @changed          = (@edit[:new] != @edit[:current])
      session[:changed] = @changed
      @lock_tree        = true
      replace_right_cell
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("report_edit__#{params[:id]}", "replace_cell__explorer")
    get_form_vars
    build_edit_screen
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_prologue
      page.replace("flash_msg_div", :partial => "layouts/flash_msg") unless @refresh_div && @refresh_div != "column_lists"
      page.replace(@refresh_div, :partial => @refresh_partial) if @refresh_div
      page.replace("chart_sample_div", :partial => "form_chart_sample") if @refresh_div == "chart_div"
      page.replace("tl_sample_div", :partial => "form_tl_sample") if @refresh_div == "tl_settings_div"
      page.replace_html("calc_#{@calc_div}_div", :text => @calc_val) if @calc_div
      page << "miqSparkle(false);"
      page << javascript_for_miq_button_visibility_changed(@changed)
      if @tl_changed  # Reload the screen if the timeline data was changed
        page.replace_html("tl_sample_div", :partial => "form_tl_sample") if @tl_field != NOTHING_STRING
      elsif @formatting_changed   # Reload the screen if the formatting pulldowns need to be reset
        page.replace_html("formatting_div", :partial => "form_formatting")
      elsif @tl_repaint
        # page << "tl.paint();"
        page << javascript_hide("notification")
      end
    end
  end

  def filter_change
    return unless load_edit("report_edit__#{params[:id]}", "replace_cell__explorer")
    @expkey = $&.to_sym if params[:button].to_s =~ /^(record|display)_filter$/
    render :update do |page|
      page << javascript_prologue
      page.replace("filter_div", :partial => "form_filter")
      page << "miqSparkle(false);"
    end
  end

  private

  def build_edit_screen
    build_tabs

    get_time_profiles # Get time profiles list (global and user specific)

    case @sb[:miq_tab].split("_")[1]
    when "1"  # Select columns
      # Add the blank choice if no table chosen yet
      #     @edit[:models].insert(0,["<Choose>", "<Choose>"]) if @edit[:new][:model] == nil && @edit[:models][0][0] != "<Choose>"
      if @edit[:new][:model].nil?
        if @edit[:models][0][0] != "<Choose>"
          @edit[:models].insert(0, ["<Choose>", "<Choose>"])
        end
      else
        if @edit[:models][0][0] == "<Choose>"
          @edit[:models].delete_at(0)
        end
      end

    when "8"  # Consolidate
      # Build group chooser arrays
      @pivots1  = @edit[:new][:fields].dup
      @pivots2  = @pivots1.dup.delete_if { |g| g[1] == @edit[:new][:pivotby1] }
      @pivots3  = @pivots2.dup.delete_if { |g| g[1] == @edit[:new][:pivotby2] }
      @pivotby1 = @edit[:new][:pivotby1]
      @pivotby2 = @edit[:new][:pivotby2]
      @pivotby3 = @edit[:new][:pivotby3]
    when "2"  # Formatting
    #     @edit[:calc_xml] = build_calc_combo_xml                                     # Get the combobox XML for any numeric fields

    when "3"  # Filter
      # Build record filter expression
      if @edit[:miq_exp] || # Is this stored as an MiqExp object
         ["new", "copy", "create"].include?(request.parameters["action"])        # or it's a new condition

        @edit[:record_filter][:exp_idx] ||= 0 # Start at first exp

        new_record_filter = @edit[:new][:record_filter]
        @edit[:record_filter][:expression] = copy_hash(new_record_filter) unless new_record_filter.blank?

        @expkey = :record_filter

        # Initialize the exp array
        exp_array(:init, @edit[:record_filter][:expression]) if @edit[:record_filter][:exp_array].nil?
        @edit[:record_filter][:exp_table] = exp_build_table(@edit[:record_filter][:expression])
        exp_get_prefill_types # Build prefill lists
        @edit[:record_filter][:exp_model] = @edit[:new][:model] # Set the model for the expression editor
      end

      # Build display filter expression
      @edit[:display_filter][:exp_idx] ||= 0 # Start at first exp

      new_display_filter = @edit[:new][:display_filter]
      @edit[:display_filter][:expression] = copy_hash(new_display_filter) unless new_display_filter.blank?

      @expkey = :display_filter

      # Initialize the exp array
      exp_array(:init, @edit[:display_filter][:expression]) if @edit[:display_filter][:exp_array].nil?

      @edit[:display_filter][:exp_table] = exp_build_table(@edit[:display_filter][:expression])

      cols = @edit[:new][:field_order]
      @edit[:display_filter][:exp_available_fields] = MiqReport.display_filter_details(cols, :field)

      cols = @edit[:new][:fields]
      @edit[:display_filter][:exp_available_tags] = MiqReport.display_filter_details(cols, :tag)
      @edit[:display_filter][:exp_model] = "_display_filter_" # Set model for display filter

      @expkey = :record_filter # Start with Record Filter showing

      if @edit[:new][:perf_interval] && !@edit[:new][:time_profile]
        set_time_profile_vars(selected_time_profile_for_pull_down, @edit[:new])
      end
    when "4"  # Summarize

      # Build sort chooser arrays(@edit[:new][:fields], :field)
      @sortby1 = @edit[:new][:sortby1]
      @sortby2 = @edit[:new][:sortby2]
      @sort1   = @edit[:new][:field_order].dup
      @sort2   = @sort1.dup.delete_if { |s| s[1] == @sortby1.split("__").first }
    when "5"  # Charts
      options = chart_fields_options
      if options.empty?
        @edit[:new][:chart_column] = nil
      else
        options[0][1] unless options.detect { |_, v| v == @edit[:new][:chart_column] }
      end

    when "6"  # Timeline
      @tl_fields = []
      @edit[:new][:fields].each do |field|
        if MiqReport.get_col_type(field[1]) == :datetime
          @tl_fields.push(field)
        end
      end
      @tl_field = @edit[:new][:tl_field]
      if @edit[:new][:tl_position] == "Last"
        @position_time = format_timezone(Time.now, "UTC", nil)
      else
        @position_time = format_timezone(Time.now - 1.year, "UTC", nil)
      end
      @timeline = true if @tl_field != NOTHING_STRING
      build_timeline_units
      @tl_last_time_choices = case @edit[:new][:tl_last_unit]
                              when "Minutes" then Array.new(12) { |t| (t * 5 + 5).to_s }
                              when "Hours"   then Array.new(24) { |t| (t + 1).to_s }
                              when "Days"    then Array.new(31) { |t| (t + 1).to_s }
                              when "Weeks"   then Array.new(4)  { |t| (t + 1).to_s }
                              when "Months"  then Array.new(12) { |t| (t + 1).to_s }
                              when "Years"   then Array.new(10) { |t| (t + 1).to_s }
                              end
      if @edit[:new][:tl_last_time].nil? && @edit[:new][:tl_last_unit] != SHOWALL_STRING
        @edit[:new][:tl_last_time] = @tl_last_time_choices.first
      end

    when "7"  # Preview
      # generate preview report when
    end

    @in_a_form = true
    if ["new", "copy", "create"].include?(request.parameters["action"])
      # drop_breadcrumb( {:name=>"Add Report", :url=>"/report/new"} )
      @gtl_url = "/new"
    else
      # drop_breadcrumb( {:name=>"Edit Report", :url=>"/report/edit"} )
      @gtl_url = "/edit"
    end
  end

  # Create the arrays for the start/end interval pulldowns
  def build_perf_interval_arrays(interval)
    case interval
    when "hourly"
      end_array = [
        ["Today", "0"],
        ["Yesterday", 1.day.to_s]
      ]
      5.times { |i| end_array.push(["#{i + 2} days ago", (i + 2).days.to_s]) }
      4.times { |i| end_array.push(["#{pluralize(i + 1, "week")} ago", (i + 1).weeks.to_s]) }
      5.times { |i| end_array.push(["#{pluralize(i + 2, "month")} ago", (i + 1).months.to_s]) }
      start_array = []
      6.times { |i| start_array.push(["#{pluralize(i + 1, "day")}", (i + 1).days.to_s]) }
      4.times { |i| start_array.push(["#{pluralize(i + 1, "week")}", (i + 1).weeks.to_s]) }
      5.times { |i| start_array.push(["#{pluralize(i + 2, "month")}", (i + 1).months.to_s]) }
      @edit[:new][:perf_end] ||= "0"
      @edit[:new][:perf_start] ||= 1.day.to_s
    when "daily"
      end_array = [
        ["Yesterday", "0"]    # Start with yesterday, since we only allow full 24 hour days in daily trending
      ]
      5.times  { |i| end_array.push(["#{i + 2} days ago", (i + 1).days.to_s]) }
      3.times  { |i| end_array.push(["#{pluralize((i + 1), "week")} ago", ((i + 1).weeks - 1.day).to_s]) }
      6.times  { |i| end_array.push(["#{pluralize((i + 1), "month")} ago", ((i + 1).months - 1.day).to_s]) }
      start_array = []
      5.times  { |i| start_array.push(["#{pluralize(i + 2, "day")}", (i + 2).days.to_s]) }
      3.times  { |i| start_array.push(["#{pluralize((i + 1), "week")}", (i + 1).weeks.to_s]) }
      11.times { |i| start_array.push(["#{pluralize((i + 1), "month")}", (i + 1).months.to_s]) }
      start_array.push(["1 year", 1.year.to_i.to_s])  # For some reason, 1.year is a float, so use to_i to get rid of decimals
      @edit[:new][:perf_end] ||= "0"
      @edit[:new][:perf_start] ||= 2.days.to_s
    end
    @edit[:start_array] = start_array
    @edit[:end_array] = end_array
  end

  # This method figures out what to put in each band unit pulldown array
  def build_timeline_units
    unless @edit[:new][:tl_bands].blank?
      split1  = BAND_UNITS.join(" ").split(@edit[:unit2]).first # Split on the second band unit
      @units1 = split1.split(" ")                               # Grab the units before the second band
      split2  = BAND_UNITS.join(" ").split(@edit[:unit1]).last    # Split on the first band unit
      split3  = split2.split(@edit[:unit3])                     # Split the rest on the 3rd unit
      @units2 = split3.first.split(" ")                         # Grab the first part for the 2nd unit
      split4  = BAND_UNITS.join(" ").split(@edit[:unit2])       # Split on the second band unit
      @units3 = split4.last.split(" ")                          # Grab the last part for the 3rd unit
    end
  end

  # Reset report column fields if model or interval was changed
  def reset_report_col_fields
    @edit[:new][:fields]          = []                    # Clear fields array
    @edit[:new][:headers]         = {}                  # Clear headers hash
    @edit[:new][:pivotby1]        = NOTHING_STRING      # Clear consolidate group fields
    @edit[:new][:pivotby2]        = NOTHING_STRING
    @edit[:new][:pivotby3]        = NOTHING_STRING
    @edit[:new][:sortby1]         = NOTHING_STRING      # Clear sort fields
    @edit[:new][:sortby2]         = NOTHING_STRING
    @edit[:new][:filter_operator] = nil
    @edit[:new][:filter_string]   = nil
    @edit[:new][:categories]      = []
    @edit[:new][:graph_type]      = nil             # Clear graph field
    @edit[:new][:chart_mode]      = nil
    @edit[:new][:chart_column]    = nil
    @edit[:new][:perf_trend_col]  = nil
    @edit[:new][:perf_trend_db]   = nil
    @edit[:new][:perf_trend_pct1] = nil
    @edit[:new][:perf_trend_pct2] = nil
    @edit[:new][:perf_trend_pct3] = nil
    @edit[:new][:perf_limit_col]  = nil
    @edit[:new][:perf_limit_val]  = nil
    @edit[:new][:record_filter]   = nil           # Clear record filter
    @edit[:new][:display_filter]  = nil         # Clear display filter
    @edit[:miq_exp]               = true
  end

  def build_tabs
    req = "edit"
    if @edit[:new][:model] == TREND_MODEL
      @tabs = [
        ["#{req}_1", _("Columns")],
        ["#{req}_3", _("Filter")],
        ["#{req}_7", _("Preview")]
      ]
    elsif Chargeback.db_is_chargeback?(@edit[:new][:model].to_s)
      @tabs = [
        ["#{req}_1", _("Columns")],
        ["#{req}_2", _("Formatting")],
        ["#{req}_3", _("Filter")],
        ["#{req}_7", _("Preview")]
      ]
    else
      @tabs = [
        ["#{req}_1", _("Columns")],
        ["#{req}_8", _("Consolidation")],
        ["#{req}_2", _("Formatting")],
        ["#{req}_9", _("Styling")],
        ["#{req}_3", _("Filter")],
        ["#{req}_4", _("Summary")],
        ["#{req}_5", _("Charts")],
        ["#{req}_6", _("Timeline")],
        ["#{req}_7", _("Preview")]
      ]
    end
    tab = @sb[:miq_tab].split("_")[1]           # Get the tab number of the active tab
    @tabs.insert(0, ["#{req}_#{tab}", ""])    # Set as the active tab in first @tabs element
  end

  # Get variables from edit form
  def get_form_vars
    @assigned_filters = []
    gfv_report_fields             # Global report fields
    gfv_move_cols_buttons         # Move cols buttons
    gfv_model                     # Model changes
    gfv_trend                     # Trend fields
    gfv_performance               # Performance fields
    gfv_chargeback                # Chargeback fields
    gfv_charts                    # Charting fields
    gfv_pivots                    # Consolidation fields
    gfv_sort                      # Summary fields
    gfv_timeline                  # Timeline fields

    # Check for key prefixes (params starting with certain keys)
    params.each do |key, value|
      # See if any headers were sent in
      @edit[:new][:headers][key.split("_")[1..-1].join("_")] = value if key.split("_").first == "hdr"

      # See if any formats were sent in
      if key.split("_").first == "fmt"
        key2 = key.gsub("___", ".")               # Put period sub table separator back into the key
        @edit[:new][:col_formats][key2.split("_")[1..-1].join("_")] = value.blank? ? nil : value.to_sym
        @formatting_changed = value.blank?
      end

      # See if any group calculation checkboxes were sent in
      gfv_key_group_calculations(key, value) if key.split("_").first == "calc"

      # See if any pivot calculation checkboxes were sent in
      gfv_key_pivot_calculations(key, value) if key.split("_").first == "pivotcalc"

      # Check for style fields
      prefix = key.split("_").first
      gfv_key_style(key, value) if prefix && prefix.starts_with?("style")
    end
  end

  # Handle params starting with "calc"
  def gfv_key_group_calculations(key, value)
    field = @edit[:new][:field_order][key.split("_").last.to_i].last  # Get the field name
    @edit[:new][:col_options][field_to_col(field)] = {
      :grouping => value.split(",").sort.map(&:to_sym).reject { |a| a == :null }
    }
  end

  # Handle params starting with "pivotcalc"
  def gfv_key_pivot_calculations(key, value)
    field = @edit[:new][:fields][key.split("_").last.to_i].last       # Get the field name
    @edit[:pivot_cols][field] = []
    value.split(',').sort.map(&:to_sym).each do |agg|
      @edit[:pivot_cols][field] << agg
      # Create new header from original header + aggregate function
      @edit[:new][:headers][field + "__#{agg}"] = @edit[:new][:headers][field] + " (#{agg.to_s.titleize})"
    end
    build_field_order
  end

  # Handle params starting with "style"
  def gfv_key_style(key, value)
    parm, f_idx, s_idx = key.split("_")                 # Get the parm type, field index, and style index
    f_idx = f_idx.to_i
    s_idx = s_idx.to_i
    f = @edit[:new][:field_order][f_idx]  # Get the field element
    field_sub_type = MiqExpression.get_col_info(f.last)[:format_sub_type]
    field_data_type = MiqExpression.get_col_info(f.last)[:data_type]
    field_name = f.last.include?(".") ? f.last.split(".").last.tr("-", ".") : f.last.split("-").last
    case parm
    when "style"  # New CSS class chosen
      if value.blank?
        @edit[:new][:col_options][field_name][:style].delete_at(s_idx)
        @edit[:new][:col_options][field_name].delete(:style) if @edit[:new][:col_options][field_name][:style].empty?
        @edit[:new][:col_options].delete(field_name) if @edit[:new][:col_options][field_name].empty?
      else
        @edit[:new][:col_options][field_name] ||= {}
        @edit[:new][:col_options][field_name][:style] ||= []
        @edit[:new][:col_options][field_name][:style][s_idx] ||= {}
        @edit[:new][:col_options][field_name][:style][s_idx][:class] = value.to_sym

        ovs = case field_data_type
              when :boolean
                ["DEFAULT", "true"]
              when :integer, :float
                ["DEFAULT", "", MiqExpression::FORMAT_SUB_TYPES.fetch_path(field_sub_type, :units) ? MiqExpression::FORMAT_SUB_TYPES.fetch_path(field_sub_type, :units).first : nil]
              else
                ["DEFAULT", ""]
              end
        op ||= ovs[0]
        val ||= ovs[1]
        suffix ||= ovs[2]

        @edit[:new][:col_options][field_name][:style][s_idx][:operator] ||= op
        @edit[:new][:col_options][field_name][:style][s_idx][:value] ||= val
        @edit[:new][:col_options][field_name][:style][s_idx][:value_suffix] ||= suffix if suffix
      end
      @refresh_div = "styling_div"
      @refresh_partial = "form_styling"
    when "styleop"  # New operator chosen
      @edit[:new][:col_options][field_name][:style][s_idx][:operator] = value
      if value == "DEFAULT"
        @edit[:new][:col_options][field_name][:style][s_idx].delete(:value) # Remove value key
        # Remove all style array elements after this one
        ((s_idx + 1)...@edit[:new][:col_options][field_name][:style].length).each_with_index do |_i, i_idx|
          @edit[:new][:col_options][field_name][:style].delete_at(i_idx)
        end
      elsif value.include?("NIL") || value.include?("EMPTY")
        @edit[:new][:col_options][field_name][:style][s_idx].delete(:value) # Remove value key
      elsif [:datetime, :date].include?(field_data_type)
        @edit[:new][:col_options][field_name][:style][s_idx][:value] = EXP_TODAY  # Set default date value
      elsif [:boolean].include?(field_data_type)
        @edit[:new][:col_options][field_name][:style][s_idx][:value] = true       # Set default boolean value
      else
        @edit[:new][:col_options][field_name][:style][s_idx][:value] = "" # Set default value
      end
      @refresh_div = "styling_div"
      @refresh_partial = "form_styling"
    when "styleval" # New value chosen
      @edit[:new][:col_options][field_name][:style][s_idx][:value] = value
    when "stylesuffix"  # New suffix chosen
      @edit[:new][:col_options][field_name][:style][s_idx][:value_suffix] = value.to_sym
      @refresh_div = "styling_div"
      @refresh_partial = "form_styling"
    end
  end

  def gfv_report_fields
    @edit[:new][:pdf_page_size] = params[:pdf_page_size] if params[:pdf_page_size]
    if params[:chosen_queue_timeout]
      @edit[:new][:queue_timeout] = params[:chosen_queue_timeout].blank? ? nil : params[:chosen_queue_timeout].to_i
    end
    @edit[:new][:row_limit] = params[:row_limit].blank? ? "" : params[:row_limit] if params[:row_limit]
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:title] = params[:title] if params[:title]
  end

  def gfv_move_cols_buttons
    if params[:button]
      move_cols_right if params[:button] == "right"
      move_cols_left if params[:button] == "left"
      move_cols_up if params[:button] == "up"
      move_cols_down if params[:button] == "down"
      move_cols_top if params[:button] == "top"
      move_cols_bottom if params[:button] == "bottom"
    end
  end

  def gfv_model
    if params[:chosen_model] && # Check for db table changed
       params[:chosen_model] != @edit[:new][:model]
      @edit[:new][:model] = params[:chosen_model]
      @edit[:new][:perf_interval] = nil                         # Clear performance interval setting
      @edit[:new][:tz] = nil
      if [:performance, :trend].include?(model_report_type(@edit[:new][:model]))
        @edit[:new][:perf_interval] ||= "daily"                 # Default to Daily
        @edit[:new][:perf_avgs] ||= "time_interval"
        @edit[:new][:tz] = session[:user_tz]
        build_perf_interval_arrays(@edit[:new][:perf_interval]) # Build the start and end arrays for the performance interval chooser
      end
      if Chargeback.db_is_chargeback?(@edit[:new][:model])
        @edit[:new][:cb_model] = Chargeback.report_cb_model(@edit[:new][:model])
        @edit[:new][:cb_interval] ||= "daily"                   # Default to Daily
        @edit[:new][:cb_interval_size] ||= 1
        @edit[:new][:cb_end_interval_offset] ||= 1
        @edit[:new][:cb_groupby] ||= "date"                     # Default to Date grouping
        @edit[:new][:tz] = session[:user_tz]
      end
      reset_report_col_fields
      build_edit_screen
      @refresh_div = "form_div"
      @refresh_partial = "form"
    end
  end

  def gfv_trend
    if params[:chosen_trend_col]
      @edit[:new][:perf_interval] ||= "daily" # Default to Daily
      @edit[:new][:perf_target_pct1] ||= 100  # Default to 100%
      if params[:chosen_trend_col] == "<Choose>"
        @edit[:new][:perf_trend_db] = nil
        @edit[:new][:perf_trend_col] = nil
      else
        @edit[:new][:perf_trend_db], @edit[:new][:perf_trend_col] = params[:chosen_trend_col].split("-")
        if MiqExpression.reporting_available_fields(@edit[:new][:model], @edit[:new][:perf_interval]).find { |af| af.last == params[:chosen_trend_col] }.first.include?("(%)")
          @edit[:new][:perf_limit_val] = 100
          @edit[:new][:perf_limit_col] = nil
          @edit[:percent_col] = true
        else
          @edit[:percent_col] = false
          @edit[:new][:perf_limit_val] = nil
        end
        build_perf_interval_arrays(@edit[:new][:perf_interval]) # Build the start and end arrays for the performance interval chooser
        @edit[:limit_cols] = VimPerformanceTrend.trend_limit_cols(@edit[:new][:perf_trend_db], @edit[:new][:perf_trend_col], @edit[:new][:perf_interval])
      end
      @refresh_div = "columns_div"
      @refresh_partial = "form_columns"
      # build_perf_interval_arrays(@edit[:new][:perf_interval])  # Build the start and end arrays for the performance interval chooser
      # @edit[:limit_cols] = VimPerformanceTrend.trend_limit_cols(@edit[:new][:perf_trend_db], @edit[:new][:perf_trend_col], @edit[:new][:perf_interval])
    elsif params[:chosen_limit_col]
      if params[:chosen_limit_col] == "<None>"
        @edit[:new][:perf_limit_col] = nil
      else
        @edit[:new][:perf_limit_col] = params[:chosen_limit_col]
        @edit[:new][:perf_limit_val] = nil
      end
      @refresh_div = "columns_div"
      @refresh_partial = "form_columns"
    elsif params[:chosen_limit_val]
      @edit[:new][:perf_limit_val] = params[:chosen_limit_val]
    elsif params[:percent1]
      @edit[:new][:perf_target_pct1] = params[:percent1].to_i
    elsif params[:percent2]
      @edit[:new][:perf_target_pct2] = params[:percent2] == "<None>" ? nil : params[:percent2].to_i
    elsif params[:percent3]
      @edit[:new][:perf_target_pct3] = params[:percent3] == "<None>" ? nil : params[:percent3].to_i
    end
  end

  def gfv_performance
    if params[:chosen_interval]
      @edit[:new][:perf_interval] = params[:chosen_interval]
      @edit[:new][:perf_start] = nil  # Clear start/end offsets
      @edit[:new][:perf_end] = nil
      build_perf_interval_arrays(@edit[:new][:perf_interval]) # Build the start and end arrays for the performance interval chooser
      reset_report_col_fields
      @refresh_div = "form_div"
      @refresh_partial = "form"
    elsif params[:perf_avgs]
      @edit[:new][:perf_avgs] = params[:perf_avgs]
    elsif params[:chosen_start]
      @edit[:new][:perf_start] = params[:chosen_start]
    elsif params[:chosen_end]
      @edit[:new][:perf_end] = params[:chosen_end]
    elsif params[:chosen_tz]
      @edit[:new][:tz] = params[:chosen_tz]
    elsif params.key?(:chosen_time_profile)
      tp = TimeProfile.find(params[:chosen_time_profile]) unless params[:chosen_time_profile].blank?
      @edit[:new][:time_profile] = params[:chosen_time_profile].blank? ? nil : params[:chosen_time_profile].to_i
      @refresh_div = "filter_div"
      @refresh_partial = "form_filter"
    end
  end

  def gfv_chargeback
    # Chargeback options
    if params.key?(:cb_show_typ)
      @edit[:new][:cb_show_typ] = params[:cb_show_typ].blank? ? nil : params[:cb_show_typ]
      @refresh_div = "filter_div"
      @refresh_partial = "form_filter"
    elsif params.key?(:cb_tag_cat)
      @refresh_div = "filter_div"
      @refresh_partial = "form_filter"
      if params[:cb_tag_cat].blank?
        @edit[:new][:cb_tag_cat] = nil
        @edit[:new][:cb_tag_value] = nil
      else
        @edit[:new][:cb_tag_cat] = params[:cb_tag_cat]
        @edit[:cb_tags] = {}
        Classification.find_by_name(params[:cb_tag_cat]).entries.each { |e| @edit[:cb_tags][e.name] = e.description }
      end
    elsif params.key?(:cb_owner_id)
      @edit[:new][:cb_owner_id] = params[:cb_owner_id].blank? ? nil : params[:cb_owner_id]
    elsif params.key?(:cb_tenant_id)
      @edit[:new][:cb_tenant_id] = params[:cb_tenant_id].blank? ? nil : params[:cb_tenant_id].to_i
    elsif params.key?(:cb_tag_value)
      @edit[:new][:cb_tag_value] = params[:cb_tag_value].blank? ? nil : params[:cb_tag_value]
    elsif params.key?(:cb_entity_id)
      @edit[:new][:cb_entity_id] = params[:cb_entity_id].blank? ? nil : params[:cb_entity_id]
    elsif params.key?(:cb_provider_id)
      @edit[:new][:cb_provider_id] = params[:cb_provider_id].blank? ? nil : params[:cb_provider_id]
      @edit[:new][:cb_entity_id] = "all"
      build_edit_screen
      @refresh_div = "form_div"
      @refresh_partial = "form"
    elsif params.key?(:cb_groupby)
      @edit[:new][:cb_groupby] = params[:cb_groupby]
    elsif params[:cb_interval]
      @edit[:new][:cb_interval] = params[:cb_interval]
      @edit[:new][:cb_interval_size] = 1
      @edit[:new][:cb_end_interval_offset] = 1
      @refresh_div = "filter_div"
      @refresh_partial = "form_filter"
    elsif params[:cb_interval_size]
      @edit[:new][:cb_interval_size] = params[:cb_interval_size].to_i
    elsif params[:cb_end_interval_offset]
      @edit[:new][:cb_end_interval_offset] = params[:cb_end_interval_offset].to_i
    end
  end

  def gfv_charts
    if params[:chosen_graph] && params[:chosen_graph] != @edit[:new][:graph_type]
      if params[:chosen_graph] == "<No chart>"
        @edit[:new][:graph_type] = nil
        # Reset other setting to initial settings if choosing <No chart>
        @edit[:new][:graph_count]  = @edit[:current][:graph_count]
        @edit[:new][:graph_other]  = @edit[:current][:graph_other]
        @edit[:new][:chart_mode]   = @edit[:current][:chart_mode]
        @edit[:new][:chart_column] = @edit[:current][:chart_column]
      else
        @edit[:new][:graph_other]  = true if @edit[:new][:graph_type].nil? # Reset other setting if choosing first chart
        @edit[:new][:graph_type]   = params[:chosen_graph] # Save graph type
        @edit[:new][:graph_count] ||= GRAPH_MAX_COUNT     # Reset graph count, if not set
        @edit[:new][:chart_mode] ||= 'counts'
        @edit[:new][:chart_column] ||= ''
      end
      @refresh_div     = "chart_div"
      @refresh_partial = "form_chart"
    end

    if params[:chart_mode] && params[:chart_mode] != @edit[:new][:chart_mode]
      @edit[:new][:chart_mode] = params[:chart_mode]
      @refresh_div             = "chart_div"
      @refresh_partial         = "form_chart"
    end

    if params[:chart_column] && params[:chart_column] != @edit[:new][:chart_column]
      @edit[:new][:chart_column] = params[:chart_column]
      @refresh_div              = "chart_sample_div"
      @refresh_partial          = "form_chart_sample"
    end

    if params[:chosen_count] && params[:chosen_count] != @edit[:new][:graph_count]
      @edit[:new][:graph_count] = params[:chosen_count]
      @refresh_div              = "chart_sample_div"
      @refresh_partial          = "form_chart_sample"
    end

    if params[:chosen_other] # If a chart is showing, set the other setting based on check box present
      chosen = (params[:chosen_other].to_s == "1")
      if @edit[:new][:graph_other] != chosen
        @edit[:new][:graph_other] = chosen
        @refresh_div              = "chart_sample_div"
        @refresh_partial          = "form_chart_sample"
      end
    end
  end

  def gfv_pivots
    if params[:chosen_pivot1] && params[:chosen_pivot1] != @edit[:new][:pivotby1]
      @edit[:new][:pivotby1] = params[:chosen_pivot1]
      if params[:chosen_pivot1] == NOTHING_STRING
        @edit[:new][:pivotby2] = NOTHING_STRING
        @edit[:new][:pivotby3] = NOTHING_STRING
      elsif params[:chosen_pivot1] == @edit[:new][:pivotby2]
        @edit[:new][:pivotby2] = @edit[:new][:pivotby3]
        @edit[:new][:pivotby3] = NOTHING_STRING
      elsif params[:chosen_pivot1] == @edit[:new][:pivotby3]
        @edit[:new][:pivotby3] = NOTHING_STRING
      end
    elsif params[:chosen_pivot2] && params[:chosen_pivot2] != @edit[:new][:pivotby2]
      @edit[:new][:pivotby2] = params[:chosen_pivot2]
      if params[:chosen_pivot2] == NOTHING_STRING || params[:chosen_pivot2] == @edit[:new][:pivotby3]
        @edit[:new][:pivotby3] = NOTHING_STRING
      end
    elsif params[:chosen_pivot3] && params[:chosen_pivot3] != @edit[:new][:pivotby3]
      @edit[:new][:pivotby3] = params[:chosen_pivot3]
    end
    if params[:chosen_pivot1] || params[:chosen_pivot2] || params[:chosen_pivot3]
      if @edit[:new][:pivotby1] == NOTHING_STRING
        @edit[:pivot_cols] = {}                       # Clear pivot_cols if no pivot grouping fields selected
      else
        @edit[:pivot_cols].delete(@edit[:new][:pivotby1])   # Remove any pivot grouping fields from pivot cols
        @edit[:pivot_cols].delete(@edit[:new][:pivotby2])
        @edit[:pivot_cols].delete(@edit[:new][:pivotby3])
      end
      build_field_order
      @refresh_div = "consolidate_div"
      @refresh_partial = "form_consolidate"
    end
  end

  def gfv_sort
    @edit[:new][:order] = params[:sort_order] if params[:sort_order]
    if params[:sort_group]                                    # If grouping changed,
      @edit[:new][:group] = params[:sort_group]
      @refresh_div = "sort_div"                               # Resend the sort tab
      @refresh_partial = "form_sort"
      if @edit[:new][:chart_mode] = 'values' && !chart_mode_values_allowed?
        @edit[:new][:chart_mode] = 'counts'
      end
    end
    @edit[:new][:hide_details] = (params[:hide_details].to_s == "1") if params[:hide_details]

    if params[:chosen_sort1] && params[:chosen_sort1] != @edit[:new][:sortby1].split("__").first
      # Remove any col options for any existing sort + suffix
      @edit[:new][:col_options].delete(@edit[:new][:sortby1].split("-").last) if @edit[:new][:sortby1].split("__")[1]
      @edit[:new][:sortby1] = params[:chosen_sort1]
      @edit[:new][:sortby2] = NOTHING_STRING if params[:chosen_sort1] == NOTHING_STRING || params[:chosen_sort1] == @edit[:new][:sortby2].split("__").first
      @refresh_div = "sort_div"
      @refresh_partial = "form_sort"
    elsif params[:chosen_sort2] && params[:chosen_sort2] != @edit[:new][:sortby2].split("__").first
      @edit[:new][:sortby2] = params[:chosen_sort2]

    # Look at the 1st sort suffix (ie. month, day_of_week, etc)
    elsif params[:sort1_suffix] && params[:sort1_suffix].to_s != @edit[:new][:sortby1].split("__")[1].to_s
      # Remove any col options for any existing sort + suffix
      @edit[:new][:col_options].delete(@edit[:new][:sortby1].split("-").last) if @edit[:new][:sortby1].split("__")[1]
      @edit[:new][:sortby1] = @edit[:new][:sortby1].split("__").first +
                              (params[:sort1_suffix].blank? ? "" : "__#{params[:sort1_suffix]}")

    # Look at the 2nd sort suffix (ie. month, day_of_week, etc)
    elsif params[:sort2_suffix] && params[:sort2_suffix].to_s != @edit[:new][:sortby2].split("__")[1].to_s
      # Remove any col options for any existing sort + suffix
      @edit[:new][:col_options].delete(@edit[:new][:sortby2].split("-").last) if @edit[:new][:sortby2].split("__")[1]
      @edit[:new][:sortby2] = @edit[:new][:sortby2].split("__").first + "__" + params[:sort2_suffix]
      @edit[:new][:sortby2] = @edit[:new][:sortby2].split("__").first +
                              (params[:sort2_suffix].blank? ? "" : "__#{params[:sort2_suffix]}")

    # Look at the break format
    else
      co_key1 = @edit[:new][:sortby1].split("-").last
      if params[:break_format] &&
         params[:break_format].to_s != @edit[:new].fetch_path(:col_options, co_key1)
        if params[:break_format].blank? || # Remove format and col key (if empty)
           params[:break_format].to_sym == MiqReport.get_col_info(@edit[:new][:sortby1])[:default_format]
          if @edit[:new][:col_options][co_key1]
            @edit[:new][:col_options][co_key1].delete(:break_format)
            @edit[:new][:col_options].delete(co_key1) if @edit[:new][:col_options][co_key1].empty?
          end
        else                            # Add col and format to col_options
          @edit[:new][:col_options][co_key1] ||= {}
          @edit[:new][:col_options][co_key1][:break_format] = params[:break_format].to_sym
        end
      end
    end

    # Clear/set up the default break label
    sort1 = @edit[:new][:sortby1].split("-").last unless @edit[:new][:sortby1].blank?
    if @edit[:new][:group] == "No"  # Clear any existing break label
      if @edit[:new].fetch_path(:col_options, sort1, :break_label)
        @edit[:new][:col_options][sort1].delete(:break_label)
        @edit[:new][:col_options].delete(sort1) if @edit[:new][:col_options][sort1].empty?
      end
    else  # Create a break label, if none there already
      unless @edit[:new].fetch_path(:col_options, sort1, :break_label)
        @edit[:new][:col_options][sort1] ||= {}
        sort, suffix = @edit[:new][:sortby1].split("__")
        @edit[:new][:col_options][sort1][:break_label] =
            @edit[:new][:field_order].collect { |f| f.first if f.last == sort }.compact.join.strip +
            (suffix ? " (#{MiqReport.date_time_break_suffixes.collect { |s| s.first if s.last == suffix }.compact.join})" : "") +
            ": "
      end
    end

    # TODO: Not allowing user to change break label until editor is changed to not use form observe
    #     if params[:break_label]
    #       @edit[:new][:col_options][@edit[:new][:sortby1].split("-").last] ||= Hash.new
    #       @edit[:new][:col_options][@edit[:new][:sortby1].split("-").last][:break_label] == params[:break_label]
    #     end
  end

  def gfv_timeline
    if params[:chosen_tl] && params[:chosen_tl] != @edit[:new][:tl_field]
      if @edit[:new][:tl_field] == NOTHING_STRING || params[:chosen_tl] == NOTHING_STRING
        @refresh_div = "tl_settings_div"
        @refresh_partial = "form_tl_settings"
        @tl_changed = true
      else
        @tl_repaint = true
      end
      @edit[:new][:tl_field] = params[:chosen_tl]
      if params[:chosen_tl] == NOTHING_STRING   # If clearing the timeline field
        @edit[:new][:tl_bands] = []      # Clear the bands
        @edit[:unit1] = NOTHING_STRING
        @edit[:unit2] = NOTHING_STRING
        @edit[:unit3] = NOTHING_STRING
      else
        if @edit[:new][:tl_bands].blank?        # If the bands are blank
          @edit[:unit1] = BAND_UNITS[1]
          @edit[:new][:tl_bands] =  [           # Create default first band
            {:width => 100, :gap => 0.0, :text => true, :unit => BAND_UNITS[1], :pixels => 100}
          ]
        end
      end
    elsif params[:chosen_position] && params[:chosen_position] != @edit[:new][:tl_position]
      @tl_changed = true
      @edit[:new][:tl_position] = params[:chosen_position]
    elsif params[:chosen_last_unit] && params[:chosen_last_unit] != @edit[:new][:tl_last_unit]
      @refresh_div = "tl_settings_div"
      @refresh_partial = "form_tl_settings"
      @tl_repaint = true
      @edit[:new][:tl_last_unit] = params[:chosen_last_unit]
      @edit[:new][:tl_last_time] = nil  # Clear out the last time numeric choice
    elsif params[:chosen_last_time] && params[:chosen_last_time] != @edit[:new][:tl_last_time]
      @tl_repaint = true
      @edit[:new][:tl_last_time] = params[:chosen_last_time]
    elsif params[:chosen_unit1] && params[:chosen_unit1] != @edit[:unit1]
      @refresh_div = "tl_settings_div"
      @refresh_partial = "form_tl_settings"
      @edit[:unit1] = params[:chosen_unit1]
      @edit[:new][:tl_bands][0][:unit] =  params[:chosen_unit1]
    elsif params[:chosen_unit2] && params[:chosen_unit2] != @edit[:unit2]
      @refresh_div = "tl_settings_div"
      @refresh_partial = "form_tl_settings"
      @tl_changed = true
      @edit[:unit2] = params[:chosen_unit2]
      if @edit[:unit2] == NOTHING_STRING
        @edit[:unit3] = NOTHING_STRING                        # Clear the 3rd band unit value
        @edit[:new][:tl_bands] = [@edit[:new][:tl_bands][0]]  # Remove the 2nd and 3rd bands
        @edit[:new][:tl_bands][0][:width] = 100
      elsif @edit[:new][:tl_bands].length < 2
        @edit[:new][:tl_bands][0][:width] = 70
        @edit[:new][:tl_bands].push(:width => 30, :height => 0.6, :gap => 0.1, :text => false, :unit => params[:chosen_unit2], :pixels => 200)
      else
        @edit[:new][:tl_bands][1][:unit] =  params[:chosen_unit2]
      end
    elsif params[:chosen_unit3] && params[:chosen_unit3] != @edit[:unit3]
      @refresh_div = "tl_settings_div"
      @refresh_partial = "form_tl_settings"
      @tl_changed = true
      @edit[:unit3] = params[:chosen_unit3]
      if @edit[:unit3] == NOTHING_STRING
        @edit[:new][:tl_bands] = @edit[:new][:tl_bands][0..1] # Remove the 3rd band
        @edit[:new][:tl_bands][1][:width] = 30
      elsif @edit[:new][:tl_bands].length < 3
        @edit[:new][:tl_bands][0][:width] = 70
        @edit[:new][:tl_bands][1][:width] = 20
        @edit[:new][:tl_bands].push(:width => 10, :height => 0.3, :gap => 0.1, :text => false, :unit => params[:chosen_unit3], :pixels => 200)
      else
        @edit[:new][:tl_bands][2][:unit] =  params[:chosen_unit3]
      end
    end
  end

  def move_cols_right
    if !params[:available_fields] || params[:available_fields].length == 0 || params[:available_fields][0] == ""
      add_flash(_("No fields were selected to move down"), :error)
    elsif params[:available_fields].length + @edit[:new][:fields].length > MAX_REPORT_COLUMNS
      add_flash(_("Fields not added: Adding the selected %{count} fields will exceed the maximum of %{max} fields") % {:count => params[:available_fields].length + @edit[:new][:fields].length, :max => MAX_REPORT_COLUMNS},
                :error)
    else
      MiqExpression.reporting_available_fields(@edit[:new][:model], @edit[:new][:perf_interval]).each do |af| # Go thru all available columns
        if params[:available_fields].include?(af[1])        # See if this column was selected to move
          unless @edit[:new][:fields].include?(af)          # Only move if it's not there already
            @edit[:new][:fields].push(af)                     # Add it to the new fields list
            if af[0].include?(":")                            # Not a base column
              table = af[0].split(" : ")[0].split(".")[-1]    # Get the table name
              table = table.singularize unless table == "OS"  # Singularize, except "OS"
              header = table + " " + af[0].split(" : ")[1]    # Add the table + col name
              temp = af[0].split(" : ")[1]
              temp_header = table == temp.split(" ")[0] ? af[0].split(" : ")[1] : temp_header = table + " " + af[0].split(" : ")[1]
            else
              header = temp_header = af[0].strip              # Base column, just use it without leading space
            end
            @edit[:new][:headers][af[1]] = temp_header        # Add the column title to the headers hash
          end
        end
      end
      @refresh_div = "column_lists"
      @refresh_partial = "column_lists"
      build_field_order
    end
  end

  def move_cols_left
    if !params[:selected_fields] || params[:selected_fields].length == 0 || params[:selected_fields][0] == ""
      add_flash(_("No fields were selected to move up"), :error)
    elsif display_filter_contains?(params[:selected_fields])
      add_flash(_("No fields were moved up"), :error)
    else
      @edit[:new][:fields].each do |nf|               # Go thru all new fields
        if params[:selected_fields].include?(nf.last) # See if this col was selected to move

          # Clear out headers and formatting
          @edit[:new][:headers].delete(nf.last)       # Delete the column name from the headers hash
          @edit[:new][:headers].delete_if { |k, _v| k.starts_with?("#{nf.last}__") } # Delete pivot calc keys
          @edit[:new][:col_formats].delete(nf.last)   # Delete the column name from the col_formats hash
          @edit[:new][:col_formats].delete_if { |k, _v| k.starts_with?("#{nf.last}__") } # Delete pivot calc keys

          # Clear out pivot field options
          if nf.last == @edit[:new][:pivotby1]              # Compress the pivotby fields if being moved left
            @edit[:new][:pivotby1] = @edit[:new][:pivotby2]
            @edit[:new][:pivotby2] = @edit[:new][:pivotby3]
            @edit[:new][:pivotby3] = NOTHING_STRING
          elsif nf.last == @edit[:new][:pivotby2]
            @edit[:new][:pivotby2] = @edit[:new][:pivotby3]
            @edit[:new][:pivotby3] = NOTHING_STRING
          elsif nf.last == @edit[:new][:pivotby3]
            @edit[:new][:pivotby3] = NOTHING_STRING
          end
          @edit[:pivot_cols].delete(nf.last)          # Delete the column name from the pivot_cols hash

          # Clear out sort options
          if @edit[:new][:sortby1] && nf.last == @edit[:new][:sortby1].split("__").first  # If deleting the first sort field
            if MiqReport.is_break_suffix?(@edit[:new][:sortby1].split("__")[1]) # If sort has a break suffix
              @edit[:new][:col_options].delete(field_to_col(@edit[:new][:sortby1])) # Remove the <col>__<suffix> from col_options
            end
            unless @edit[:new][:group] == "No"  # If we were grouping, remove all col_options :group keys
              @edit[:new][:col_options].each do |co_key, co_val|
                co_val.delete(:grouping)                                      # Remove :group key
                @edit[:new][:col_options].delete(co_key) if co_val.empty? # Remove the col, if empty
              end
            end
            @edit[:new][:sortby1] = NOTHING_STRING
            @edit[:new][:sortby2] = NOTHING_STRING
          end
          if @edit[:new][:sortby1] && nf.last == @edit[:new][:sortby2].split("__").first  # If deleting the second sort field
            @edit[:new][:sortby2] = NOTHING_STRING
          end

          # Clear out timeline options
          if nf.last == @edit[:new][:tl_field]        # If deleting the timeline field
            @edit[:new][:tl_field] = NOTHING_STRING
            @edit[:unit1] = NOTHING_STRING
            @edit[:unit2] = NOTHING_STRING
            @edit[:unit3] = NOTHING_STRING
            @edit[:new][:tl_bands] = []
          end

          @edit[:new][:col_options].delete(field_to_col(nf.last)) # Remove this column from the col_options hash
        end
      end
      @edit[:new][:fields].delete_if { |nf| params[:selected_fields].include?(nf.last) } # Remove selected fields
      @refresh_div = "column_lists"
      @refresh_partial = "column_lists"
      build_field_order
    end
  end

  # See if any of the fields passed in are present in the display filter expression
  def display_filter_contains?(fields)
    return false if @edit[:new][:display_filter].nil? # No display filter defined
    exp = @edit[:new][:display_filter].inspect
    @edit[:new][:fields].each do |f|          # Go thru all of the selected fields
      if fields.include?(f.last)              # Is this field being removed?
        add_flash(_("%{name} is currently being used in the Display Filter") %
                  {:name => f.first}, :error) if exp.include?(f.last)
      end
    end
    !@flash_array.nil?
  end

  def move_cols_up
    if !params[:selected_fields] || params[:selected_fields].length == 0 || params[:selected_fields][0] == ""
      add_flash(_("No fields were selected to move up"), :error)
      return
    end
    consecutive, first_idx, last_idx = selected_consecutive?
    if !consecutive
      add_flash(_("Select only one or consecutive fields to move up"), :error)
    else
      if first_idx > 0
        @edit[:new][:fields][first_idx..last_idx].reverse_each do |field|
          pulled = @edit[:new][:fields].delete(field)
          @edit[:new][:fields].insert(first_idx - 1, pulled)
        end
      end
      @refresh_div = "column_lists"
      @refresh_partial = "column_lists"
    end
    @selected = params[:selected_fields]
    build_field_order
  end

  def move_cols_down
    if !params[:selected_fields] || params[:selected_fields].length == 0 || params[:selected_fields][0] == ""
      add_flash(_("No fields were selected to move down"), :error)
      return
    end
    consecutive, first_idx, last_idx = selected_consecutive?
    if !consecutive
      add_flash(_("Select only one or consecutive fields to move down"), :error)
    else
      if last_idx < @edit[:new][:fields].length - 1
        insert_idx = last_idx + 1   # Insert before the element after the last one
        insert_idx = -1 if last_idx == @edit[:new][:fields].length - 2 # Insert at end if 1 away from end
        @edit[:new][:fields][first_idx..last_idx].each do |field|
          pulled = @edit[:new][:fields].delete(field)
          @edit[:new][:fields].insert(insert_idx, pulled)
        end
      end
      @refresh_div = "column_lists"
      @refresh_partial = "column_lists"
    end
    @selected = params[:selected_fields]
    build_field_order
  end

  def move_cols_top
    if !params[:selected_fields] || params[:selected_fields].length == 0 || params[:selected_fields][0] == ""
      add_flash(_("No fields were selected to move to the top"), :error)
      return
    end
    consecutive, first_idx, last_idx = selected_consecutive?
    if !consecutive
      add_flash(_("Select only one or consecutive fields to move to the top"), :error)
    else
      if first_idx > 0
        @edit[:new][:fields][first_idx..last_idx].reverse_each do |field|
          pulled = @edit[:new][:fields].delete(field)
          @edit[:new][:fields].unshift(pulled)
        end
      end
      @refresh_div = "column_lists"
      @refresh_partial = "column_lists"
    end
    @selected = params[:selected_fields]
    build_field_order
  end

  def move_cols_bottom
    if !params[:selected_fields] || params[:selected_fields].length == 0 || params[:selected_fields][0] == ""
      add_flash(_("No fields were selected to move to the bottom"), :error)
      return
    end
    consecutive, first_idx, last_idx = selected_consecutive?
    if !consecutive
      add_flash(_("Select only one or consecutive fields to move to the bottom"), :error)
    else
      if last_idx < @edit[:new][:fields].length - 1
        @edit[:new][:fields][first_idx..last_idx].each do |field|
          pulled = @edit[:new][:fields].delete(field)
          @edit[:new][:fields].push(pulled)
        end
      end
      @refresh_div = "column_lists"
      @refresh_partial = "column_lists"
    end
    @selected = params[:selected_fields]
    build_field_order
  end

  def selected_consecutive?
    first_idx = last_idx = 0
    @edit[:new][:fields].each_with_index do |nf, idx|
      first_idx = idx if nf[1] == params[:selected_fields].first
      if nf[1] == params[:selected_fields].last
        last_idx = idx
        break
      end
    end
    if last_idx - first_idx + 1 > params[:selected_fields].length
      return [false, first_idx, last_idx]
    else
      return [true, first_idx, last_idx]
    end
  end

  # Set record variables to new values
  def set_record_vars(rpt)
    # Set the simple string/number fields
    rpt.template_type = "report"
    rpt.name          = @edit[:new][:name].to_s.strip
    rpt.title         = @edit[:new][:title].to_s.strip
    rpt.db            = @edit[:new][:model]
    rpt.rpt_group     = @edit[:new][:rpt_group]
    rpt.rpt_type      = @edit[:new][:rpt_type]
    rpt.priority      = @edit[:new][:priority]
    rpt.categories    = @edit[:new][:categories]
    rpt.col_options   = @edit[:new][:col_options]

    rpt.order = @edit[:new][:sortby1].nil? ? nil : @edit[:new][:order]

    # Set the graph fields
    if @edit[:new][:sortby1] == NOTHING_STRING || @edit[:new][:graph_type].nil?
      rpt.dims  = nil
      rpt.graph = nil
    else
      if @edit[:new][:graph_type] =~ /^(Pie|Donut)/ # Pie and Donut charts must be set to 1 dimension
        rpt.dims = 1
      else
        rpt.dims = @edit[:new][:sortby2] == NOTHING_STRING ? 1 : 2  # Set dims to 1 or 2 based on presence of sortby2
      end
      if @edit[:new][:chart_mode] == 'values' && @edit[:new][:chart_column].blank?
        options = chart_fields_options
        @edit[:new][:chart_column] = options[0][1] unless options.empty?
      end
      rpt.graph = {
        :type   => @edit[:new][:graph_type],
        :mode   => @edit[:new][:chart_mode],
        :column => @edit[:new][:chart_column],
        :count  => @edit[:new][:graph_count],
        :other  => @edit[:new][:graph_other],
      }
    end

    # Set the conditions field (expression)
    if !@edit[:new][:record_filter].nil? && @edit[:new][:record_filter]["???"].nil?
      rpt.conditions = MiqExpression.new(@edit[:new][:record_filter])
    else
      rpt.conditions = nil
    end

    # Set the display_filter field (expression)
    if !@edit[:new][:display_filter].nil? && @edit[:new][:display_filter]["???"].nil?
      rpt.display_filter = MiqExpression.new(@edit[:new][:display_filter])
    else
      rpt.display_filter = nil
    end

    # Set the performance options
    rpt.db_options = Hash.new
    if model_report_type(rpt.db) == :performance
      rpt.db_options[:interval]     = @edit[:new][:perf_interval]
      rpt.db_options[:calc_avgs_by] = @edit[:new][:perf_avgs]
      rpt.db_options[:end_offset]   = @edit[:new][:perf_end].to_i
      rpt.db_options[:start_offset] = @edit[:new][:perf_end].to_i + @edit[:new][:perf_start].to_i
    elsif model_report_type(rpt.db) == :trend
      rpt.db_options[:rpt_type]     = "trend"
      rpt.db_options[:interval]     = @edit[:new][:perf_interval]
      rpt.db_options[:end_offset]   = @edit[:new][:perf_end].to_i
      rpt.db_options[:start_offset] = @edit[:new][:perf_end].to_i + @edit[:new][:perf_start].to_i
      rpt.db_options[:trend_db]     = @edit[:new][:perf_trend_db]
      rpt.db_options[:trend_col]    = @edit[:new][:perf_trend_col]
      rpt.db_options[:limit_col]    = @edit[:new][:perf_limit_col] if @edit[:new][:perf_limit_col]
      rpt.db_options[:limit_val]    = @edit[:new][:perf_limit_val] if @edit[:new][:perf_limit_val]
      rpt.db_options[:target_pcts]  = []
      rpt.db_options[:target_pcts].push(@edit[:new][:perf_target_pct1])
      rpt.db_options[:target_pcts].push(@edit[:new][:perf_target_pct2]) if @edit[:new][:perf_target_pct2]
      rpt.db_options[:target_pcts].push(@edit[:new][:perf_target_pct3]) if @edit[:new][:perf_target_pct3]
    elsif Chargeback.db_is_chargeback?(rpt.db)
      rpt.db_options[:rpt_type]     = @edit[:new][:model]
      options                       = {}  # CB options go in db_options[:options] key
      options[:interval]            = @edit[:new][:cb_interval]
      options[:interval_size]       = @edit[:new][:cb_interval_size]
      options[:end_interval_offset] = @edit[:new][:cb_end_interval_offset]
      if @edit[:new][:cb_show_typ] == "owner"
        options[:owner] = @edit[:new][:cb_owner_id]
      elsif @edit[:new][:cb_show_typ] == "tenant"
        options[:tenant_id] = @edit[:new][:cb_tenant_id]
      elsif @edit[:new][:cb_show_typ] == "tag"
        if @edit[:new][:cb_tag_cat] && @edit[:new][:cb_tag_value]
          options[:tag] = "/managed/#{@edit[:new][:cb_tag_cat]}/#{@edit[:new][:cb_tag_value]}"
        end
      elsif @edit[:new][:cb_show_typ] == "entity"
        options[:provider_id] = @edit[:new][:cb_provider_id]
        options[:entity_id] = @edit[:new][:cb_entity_id]
      end

      rpt.db_options[:options] = options
    end

    rpt.time_profile_id = @edit[:new][:time_profile]
    if @edit[:new][:time_profile]
      time_profile = TimeProfile.find_by_id(@edit[:new][:time_profile])
      rpt.tz = time_profile.tz
    end

    # Set the timeline field
    if @edit[:new][:tl_field] == NOTHING_STRING
      rpt.timeline = nil
    else
      rpt.timeline = Hash.new
      rpt.timeline[:field] = @edit[:new][:tl_field]
      rpt.timeline[:position] = @edit[:new][:tl_position]
      rpt.timeline[:bands] = @edit[:new][:tl_bands]
      if @edit[:new][:tl_last_unit] == SHOWALL_STRING
        rpt.timeline[:last_unit] = rpt.timeline[:last_time] = nil
      else
        rpt.timeline[:last_unit] = @edit[:new][:tl_last_unit]
        rpt.timeline[:last_time] = @edit[:new][:tl_last_time]
      end
    end

    # Set the line break group field
    if @edit[:new][:sortby1] == NOTHING_STRING  # If no sort fields
      rpt.group = nil               # Clear line break group
    else                            # Otherwise, check the setting
      case @edit[:new][:group]
      when "Yes"
        rpt.group = "y"
      when "Counts"
        rpt.group = "c"
      else
        rpt.group = nil
      end
    end

    # Set defaults, if not present
    rpt.rpt_group ||= "Custom"
    rpt.rpt_type ||= "Custom"

    rpt.cols = []
    rpt.col_order = []
    rpt.col_formats = []
    rpt.headers = []
    rpt.include = Hash.new
    rpt.sortby = @edit[:new][:sortby1] == NOTHING_STRING ? nil : []  # Clear sortby if sortby1 not present, else set up array

    # Add in the chargeback static fields
    if Chargeback.db_is_chargeback?(rpt.db) # For chargeback, add in static fields
      rpt.cols = %w(start_date display_range)
      name_col = @edit[:new][:model].constantize.report_name_field
      rpt.cols += [name_col]
      if @edit[:new][:cb_groupby] == "date"
        rpt.col_order = ["display_range", name_col]
        rpt.sortby = ["start_date", name_col]
      elsif @edit[:new][:cb_groupby] == "vm"
        rpt.col_order = [name_col, "display_range"]
        rpt.sortby = [name_col, "start_date"]
      end
      rpt.col_order.each do |c|
        rpt.headers.push(Dictionary.gettext(c, :type => :column, :notfound => :titleize))
        rpt.col_formats.push(nil) # No formatting needed on the static cols
      end
      rpt.col_options = @edit[:new][:model].constantize.report_col_options
      rpt.order = "Ascending"
      rpt.group = "y"
      rpt.tz = @edit[:new][:tz]
    end

    # Remove when we support user sorting of trend reports
    if rpt.db == TREND_MODEL
      rpt.sortby = ["resource_name"]
      rpt.order = "Ascending"
    end

    # Build column related report fields
    @pg1 = @pg2 = @pg3 = nil                            # Init the pivot group cols
    @edit[:new][:fields].each do |field_entry|          # Go thru all of the fields
      field = field_entry[1]                            # Get the encoded fully qualified field name

      if @edit[:new][:pivotby1] != NOTHING_STRING && # If we are doing pivoting and
         @edit[:pivot_cols].key?(field)              # this is a pivot calc column
        @edit[:pivot_cols][field].each do |calc_typ|    # Add header/format/col_order for each calc type
          rpt.headers.push(@edit[:new][:headers][field + "__#{calc_typ}"])
          rpt.col_formats.push(@edit[:new][:col_formats][field + "__#{calc_typ}"])
          add_field_to_col_order(rpt, field + "__#{calc_typ}")
        end
      else                                              # Normal field, set header/format/col_order
        rpt.headers.push(@edit[:new][:headers][field])
        rpt.col_formats.push(@edit[:new][:col_formats][field])
        add_field_to_col_order(rpt, field)
      end
    end
    rpt.rpt_options ||= {}
    rpt.rpt_options.delete(:pivot)
    unless @pg1.nil?                                    # Build the pivot group_cols array
      rpt.rpt_options[:pivot] = {}
      rpt.rpt_options[:pivot][:group_cols] = []
      rpt.rpt_options[:pivot][:group_cols].push(@pg1)
      rpt.rpt_options[:pivot][:group_cols].push(@pg2) unless @pg2.nil?
      rpt.rpt_options[:pivot][:group_cols].push(@pg3) unless @pg3.nil?
    end
    if @edit[:new][:group] != "No" || @edit[:new][:row_limit].blank?
      rpt.rpt_options.delete(:row_limit)
    else
      rpt.rpt_options[:row_limit] = @edit[:new][:row_limit].to_i
    end

    # Add pdf page size to rpt_options
    rpt.rpt_options ||= {}
    rpt.rpt_options[:pdf] ||= {}
    rpt.rpt_options[:pdf][:page_size] = @edit[:new][:pdf_page_size] || DEFAULT_PDF_PAGE_SIZE

    rpt.rpt_options[:queue_timeout] = @edit[:new][:queue_timeout]

    # Add hide detail rows option, if grouping
    if rpt.group.nil?
      rpt.rpt_options.delete(:summary)
    else
      rpt.rpt_options[:summary] ||= {}
      rpt.rpt_options[:summary][:hide_detail_rows] = @edit[:new][:hide_details]
    end

    user = current_user
    rpt.user = user
    rpt.miq_group = user.current_group
  end

  def add_field_to_col_order(rpt, field)
    # Get the sort columns, removing the suffix if it exists
    sortby1 = MiqReport.is_break_suffix?(@edit[:new][:sortby1].split("__")[1]) ?
        @edit[:new][:sortby1].split("__").first :
        @edit[:new][:sortby1]
    sortby2 = MiqReport.is_break_suffix?(@edit[:new][:sortby2].split("__")[1]) ?
        @edit[:new][:sortby2].split("__").first :
        @edit[:new][:sortby2]

    if field.include?(".")                            # Has a period, so it's an include
      tables = field.split("-")[0].split(".")[1..-1]  # Get the list of tables from before the hyphen
      inc_hash = rpt.include                          # Start at the main hash
      tables.each_with_index do |table, idx|
        inc_hash[table] ||= {}                  # Create hash for the table, if it's not there already
        if idx == tables.length - 1                   # We're at the end of the field name, so add the column
          inc_hash[table]["columns"] ||= []    # Create the columns array for this table
          f = field.split("-")[1].split("__").first   # Grab the field name after the hyphen, before the "__"
          inc_hash[table]["columns"].push(f) unless inc_hash[table]["columns"].include?(f) # Add the field to the columns, if not there

          table_field = tables.join('.') + "." + field.split("-")[1]
          rpt.col_order.push(table_field)             # Add the table.field to the col_order array

          if field == sortby1                         # Is this the first sort field?
            rpt.sortby = [table_field] + rpt.sortby   # Put the field first in the sortby array
          elsif field == @edit[:new][:sortby2]        # Is this the second sort field?
            rpt.sortby.push(table_field)              # Add the field to the sortby array
          end

          if field == @edit[:new][:pivotby1]          # Save the group fields
            @pg1 = table_field
          elsif field == @edit[:new][:pivotby2]
            @pg2 = table_field
          elsif field == @edit[:new][:pivotby3]
            @pg3 = table_field
          end
        else                                          # Set up for the next embedded include hash
          inc_hash[table]["include"] ||= {}     # Create include hash for next level
          inc_hash = inc_hash[table]["include"]       # Point to the new hash
        end
      end
    else                                              # No period, this is a main table column
      if field.include?("__")                         # Check for pivot calculated field
        f = field.split("-")[1].split("__").first     # Grab the field name after the hyphen, before the "__"
        rpt.cols.push(f) unless rpt.cols.include?(f)  # Add the original field, if not already there
      else
        rpt.cols.push(field.split("-")[1])            # Grab the field name after the hyphen
      end
      rpt.col_order.push(field.split("-")[1])         # Add the field to the col_order array
      if field == sortby1                             # Is this the first sort field?
        rpt.sortby = [@edit[:new][:sortby1].split("-")[1]] + rpt.sortby # Put the field first in the sortby array
      elsif field == sortby2                          # Is this the second sort field?
        rpt.sortby.push(@edit[:new][:sortby2].split("-")[1])  # Add the field to the sortby array
      end
      if field == @edit[:new][:pivotby1]          # Save the group fields
        @pg1 = field.split("-")[1]
      elsif field == @edit[:new][:pivotby2]
        @pg2 = field.split("-")[1]
      elsif field == @edit[:new][:pivotby3]
        @pg3 = field.split("-")[1]
      end
    end
  end

  # Set form variables for edit
  def set_form_vars
    @edit = {}
    @edit[:rpt_id] = @rpt.id  # Save a record id to use it later to look a record
    @edit[:rpt_title] = @rpt.title
    @edit[:rpt_name] = @rpt.name
    @edit[:new] = {}
    @edit[:key] = "report_edit__#{@rpt.id || "new"}"
    if params[:pressed] == "miq_report_copy"
      @edit[:new][:rpt_group] = "Custom"
      @edit[:new][:rpt_type] = "Custom"
    else
      @edit[:new][:rpt_group] = @rpt.rpt_group
      @edit[:new][:rpt_type] = @rpt.rpt_type
    end

    # Get the simple string/number fields
    @edit[:new][:name] = @rpt.name
    @edit[:new][:title] = @rpt.title
    @edit[:new][:model] = @rpt.db
    @edit[:new][:priority] = @rpt.priority
    @edit[:new][:order] = @rpt.order.blank? ? "Ascending" : @rpt.order

    #   @edit[:new][:graph] = @rpt.graph
    # Replaced above line to handle new graph settings Hash
    if @rpt.graph.kind_of?(Hash)
      @edit[:new][:graph_type]   = @rpt.graph[:type]
      @edit[:new][:graph_count]  = @rpt.graph[:count]
      @edit[:new][:chart_mode]   = @rpt.graph[:mode]
      @edit[:new][:chart_column] = @rpt.graph[:column]
      @edit[:new][:graph_other]  = @rpt.graph[:other] ? @rpt.graph[:other] : false
    else
      @edit[:new][:graph_type]   = @rpt.graph
      @edit[:new][:graph_count]  = GRAPH_MAX_COUNT
      @edit[:new][:chart_mode]   = 'counts'
      @edit[:new][:chart_column] = ''
      @edit[:new][:graph_other]  = true
    end

    @edit[:new][:dims] = @rpt.dims
    @edit[:new][:categories] = @rpt.categories
    @edit[:new][:categories] ||= []

    @edit[:new][:col_options] = @rpt.col_options.blank? ? {} : @rpt.col_options

    # Initialize options
    @edit[:new][:perf_interval] = nil
    @edit[:new][:perf_start] = nil
    @edit[:new][:perf_end] = nil
    @edit[:new][:tz] = nil
    @edit[:new][:perf_trend_db] = nil
    @edit[:new][:perf_trend_col] = nil
    @edit[:new][:perf_limit_col] = nil
    @edit[:new][:perf_limit_val] = nil
    @edit[:new][:perf_target_pct1] = nil
    @edit[:new][:perf_target_pct2] = nil
    @edit[:new][:perf_target_pct3] = nil
    @edit[:new][:cb_interval] = nil
    @edit[:new][:cb_interval_size] = nil
    @edit[:new][:cb_end_interval_offset] = nil

    if [:performance, :trend].include?(model_report_type(@rpt.db))
      @edit[:new][:perf_interval] = @rpt.db_options[:interval]
      @edit[:new][:perf_avgs] = @rpt.db_options[:calc_avgs_by]
      @edit[:new][:perf_end] = @rpt.db_options[:end_offset].to_s
      @edit[:new][:perf_start] = (@rpt.db_options[:start_offset] - @rpt.db_options[:end_offset]).to_s
      @edit[:new][:tz] = @rpt.tz ? @rpt.tz : session[:user_tz]    # Set the timezone, default to user's
      if @rpt.time_profile
        @edit[:new][:time_profile] = @rpt.time_profile_id
        @edit[:new][:time_profile_tz] = @rpt.time_profile.tz
      else
        set_time_profile_vars(selected_time_profile_for_pull_down, @edit[:new])
      end
      @edit[:new][:perf_trend_db] = @rpt.db_options[:trend_db]
      @edit[:new][:perf_trend_col] = @rpt.db_options[:trend_col]
      @edit[:new][:perf_limit_col] = @rpt.db_options[:limit_col]
      @edit[:new][:perf_limit_val] = @rpt.db_options[:limit_val]
      @edit[:new][:perf_target_pct1], @edit[:new][:perf_target_pct2], @edit[:new][:perf_target_pct3] = @rpt.db_options[:target_pcts]
    elsif Chargeback.db_is_chargeback?(@rpt.db)
      @edit[:new][:tz] = @rpt.tz ? @rpt.tz : session[:user_tz]    # Set the timezone, default to user's
      options = @rpt.db_options[:options]
      if options.key?(:owner) # Get the owner options
        @edit[:new][:cb_show_typ] = "owner"
        @edit[:new][:cb_owner_id] = options[:owner]
      elsif options.key?(:tenant_id) # Get the tenant options
        @edit[:new][:cb_show_typ] = "tenant"
        @edit[:new][:cb_tenant_id] = options[:tenant_id]
      elsif options.key?(:tag)  # Get the tag options
        @edit[:new][:cb_show_typ] = "tag"
        @edit[:new][:cb_tag_cat] = options[:tag].split("/")[-2]
        @edit[:new][:cb_tag_value] = options[:tag].split("/")[-1]
        @edit[:cb_tags] = {}
        cat = Classification.find_by_name(@edit[:new][:cb_tag_cat])
        cat.entries.each { |e| @edit[:cb_tags][e.name] = e.description } if cat  # Collect the tags, if category is valid
      elsif options.key?(:entity_id)
        @edit[:new][:cb_show_typ] = "entity"
        @edit[:new][:cb_entity_id] = options[:entity_id]
        @edit[:new][:cb_provider_id] = options[:provider_id]
      end

      @edit[:new][:cb_model] = Chargeback.report_cb_model(@rpt.db)
      @edit[:new][:cb_interval] = options[:interval]
      @edit[:new][:cb_interval_size] = options[:interval_size]
      @edit[:new][:cb_end_interval_offset] = options[:end_interval_offset]
      @edit[:new][:cb_groupby] = @rpt.sortby.nil? || @rpt.sortby.first == "start_date" ? "date" : "vm"
    end

    # Only show chargeback users choice if an admin
    if admin_user?
      @edit[:cb_users] = {}
      User.all.each { |u| @edit[:cb_users][u.userid] = u.name }
      @edit[:cb_tenant] = {}
      Tenant.all.each { |t| @edit[:cb_tenant][t.id] = t.name }
    else
      @edit[:new][:cb_show_typ] = "owner"
      @edit[:new][:cb_owner_id] = session[:userid]
      @edit[:cb_owner_name] = current_user.name
    end

    # Get chargeback tags
    cats = Classification.categories.collect { |c| c if c.show }.compact  # Get categories, sort by name, remove nils
    cats.delete_if { |c| c.read_only? || c.entries.length == 0 }  # Remove categories that are read only or have no entries
    @edit[:cb_cats] = {}
    cats.each { |c| @edit[:cb_cats][c.name] = c.description }

    @edit[:cb_providers] = {}
    @edit[:cb_providers][:container_project] = {}
    @edit[:cb_providers][:vm] = {} # Fill this in if entity show type it ever becomes relevent for VMs
    @edit[:cb_entities_by_provider_id] = {}
    ManageIQ::Providers::ContainerManager.all.each do |provider|
      @edit[:cb_providers][:container_project][provider.name] = provider.id
      @edit[:cb_entities_by_provider_id][provider.id] = {}
      provider.container_projects.all.each do |project|
        @edit[:cb_entities_by_provider_id][provider.id][project.id] = project.name
      end
    end

    # Build trend limit cols array
    if model_report_type(@rpt.db) == :trend
      @edit[:limit_cols] = VimPerformanceTrend.trend_limit_cols(@edit[:new][:perf_trend_db], @edit[:new][:perf_trend_col], @edit[:new][:perf_interval])
    end

    # Build performance interval select arrays, if needed
    if [:performance, :trend].include?(model_report_type(@rpt.db))
      build_perf_interval_arrays(@edit[:new][:perf_interval]) # Build the start and end arrays for the performance interval chooser
    end

    expkey = :record_filter
    @edit[expkey] ||= {}                                                # Create hash for this expression, if needed
    @edit[expkey][:record_filter] = []                               # Store exps in an array
    @edit[expkey][:exp_idx] ||= 0
    @edit[expkey][:expression] = {"???" => "???"}                           # Set as new exp element
    # Get the conditions MiqExpression
    if @rpt.conditions.kind_of?(MiqExpression)
      @edit[:new][:record_filter] = @rpt.conditions.exp
      @edit[:miq_exp]             = true
    elsif @rpt.conditions.nil?
      @edit[:new][:record_filter] = nil
      @edit[:new][:record_filter] = @edit[expkey][:expression]                  # Copy to new exp
      @edit[:miq_exp]             = true
    end

    # Get the display_filter MiqExpression
    @edit[:new][:display_filter] = @rpt.display_filter.nil? ? nil : @rpt.display_filter.exp
    expkey = :display_filter
    @edit[expkey] ||= {}                                                # Create hash for this expression, if needed
    @edit[expkey][:expression] = []                                    # Store exps in an array
    @edit[expkey][:exp_idx] ||= 0                                           # Start at first exp
    @edit[expkey][:expression] = {"???" => "???"}                           # Set as new exp element
    # Build display filter expression
    @edit[:new][:display_filter] = @edit[expkey][:expression] if @edit[:new][:display_filter].nil?              # Copy to new exp

    # Get timeline fields
    @edit[:tl_last_units] = []
    BAND_UNITS[1..-2].each { |u| @edit[:tl_last_units].push u.pluralize }
    @edit[:unit1]              = NOTHING_STRING # Default units and tl field to nothing
    @edit[:unit2]              = NOTHING_STRING
    @edit[:unit3]              = NOTHING_STRING
    @edit[:new][:tl_field]     = NOTHING_STRING
    @edit[:new][:tl_position]  = "Last"
    @edit[:new][:tl_last_unit] = SHOWALL_STRING
    @edit[:new][:tl_last_time] = nil
    if @rpt.timeline.kind_of?(Hash)    # Timeline has any data
      @edit[:new][:tl_field]     = @rpt.timeline[:field]     unless @rpt.timeline[:field].blank?
      @edit[:new][:tl_position]  = @rpt.timeline[:position]  unless @rpt.timeline[:position].blank?
      @edit[:new][:tl_last_unit] = @rpt.timeline[:last_unit] unless @rpt.timeline[:last_unit].blank?
      @edit[:new][:tl_last_time] = @rpt.timeline[:last_time] unless @rpt.timeline[:last_time].blank?
      @edit[:new][:tl_bands]     = @rpt.timeline[:bands]
      unless @rpt.timeline[:bands].blank?
        @edit[:unit1] = @rpt.timeline[:bands][0][:unit].capitalize
        @edit[:unit2] = @rpt.timeline[:bands][1][:unit].capitalize if @rpt.timeline[:bands].length > 1
        @edit[:unit3] = @rpt.timeline[:bands][2][:unit].capitalize if @rpt.timeline[:bands].length > 2
      end
    else
      @edit[:new][:tl_bands] = []
    end

    # Get the pdf page size, if present
    if @rpt.rpt_options.kind_of?(Hash) && @rpt.rpt_options[:pdf]
      @edit[:new][:pdf_page_size] = @rpt.rpt_options[:pdf][:page_size] || DEFAULT_PDF_PAGE_SIZE
    else
      @edit[:new][:pdf_page_size] = DEFAULT_PDF_PAGE_SIZE
    end

    # Get the hide details setting, if present
    if @rpt.rpt_options.kind_of?(Hash) && @rpt.rpt_options[:summary]
      @edit[:new][:hide_details] = @rpt.rpt_options[:summary][:hide_detail_rows]
    else
      @edit[:new][:hide_details] = false
    end

    # Get the timeout if present
    if @rpt.rpt_options.kind_of?(Hash) && @rpt.rpt_options[:queue_timeout]
      @edit[:new][:queue_timeout] = @rpt.rpt_options[:queue_timeout]
    else
      @edit[:new][:queue_timeout] = nil
    end

    case @rpt.group
    when "y"
      @edit[:new][:group] = "Yes"
    when "c"
      @edit[:new][:group] = "Counts"
    else
      @edit[:new][:group] = "No"
      @edit[:new][:row_limit] = @rpt.rpt_options[:row_limit].to_s if @rpt.rpt_options
    end

    # build selected fields array from the report record
    @edit[:new][:sortby1]  = NOTHING_STRING # Initialize sortby fields to nothing
    @edit[:new][:sortby2]  = NOTHING_STRING
    @edit[:new][:pivotby1] = NOTHING_STRING # Initialize groupby fields to nothing
    @edit[:new][:pivotby2] = NOTHING_STRING
    @edit[:new][:pivotby3] = NOTHING_STRING
    if params[:pressed] == "miq_report_new"
      @edit[:new][:fields]      = []
      @edit[:new][:categories]  = []
      @edit[:new][:headers]     = {}
      @edit[:new][:col_formats] = {}
      @edit[:pivot_cols]        = {}
    else
      build_selected_fields(@rpt)           # Create the field related @edit arrays and hashes
    end

    # Rebuild the tag descriptions in the new fields array to match the ones in available fields
    @edit[:new][:fields].each do |nf|
      tag = nf.first.split(':')
      if nf.first.include?("Managed :")
        entry = MiqExpression.reporting_available_fields(@edit[:new][:model], @edit[:new][:perf_interval]).find { |a| a.last == nf.last }
        nf[0] = entry ? entry.first : "#{tag} (Category not found)"
      end
    end

    @edit[:current] = ["copy", "new"].include?(params[:action]) ? {} : copy_hash(@edit[:new])

    unless @edit[:models] # Only create once
      @edit[:models] = []
      MiqReport.reportable_models.each do |m|
        @edit[:models].push([Dictionary.gettext(m, :type => :model, :notfound => :titleize, :plural => true), m])
      end
    end

    # Only show chargeback users choice if an admin
    if admin_user?
      @edit[:cb_users] = {}
      User.all.each { |u| @edit[:cb_users][u.userid] = u.name }
      @edit[:cb_tenant] = {}
      Tenant.all.each { |t| @edit[:cb_tenant][t.id] = t.name }
    else
      @edit[:new][:cb_show_typ] = "owner"
      @edit[:new][:cb_owner_id] = session[:userid]
    end

    # For trend reports, check for percent field chosen
    if @rpt.db && @rpt.db == TREND_MODEL &&
       MiqExpression.reporting_available_fields(@edit[:new][:model], @edit[:new][:perf_interval]).find do|af|
         af.last ==
         @edit[:new][:perf_trend_db] + "-" + @edit[:new][:perf_trend_col]
       end.first.include?("(%)")
      @edit[:percent_col] = true
    end
  end

  # Build the :fields array and :headers hash from the rpt record cols and includes hashes
  def build_selected_fields(rpt)
    fields = []
    headers = {}
    col_formats = {}
    pivot_cols = {}
    rpt.col_formats ||= Array.new(rpt.col_order.length)   # Create array of nils if col_formats not present (backward compat)
    rpt.col_order.each_with_index do |col, idx|
      if !col.include?(".")  # Main table field
        field_key = rpt.db + "-" + col
        field_value = friendly_model_name(rpt.db) +
                      Dictionary.gettext(rpt.db + "." + col.split("__").first, :type => :column, :notfound => :titleize)
      else                      # Included table field
        inc_string = find_includes(col.split("__").first, rpt.include)  # Get the full include string
        field_key = rpt.db + "." + inc_string.to_s + "-" + col.split(".").last
        if inc_string.to_s.ends_with?(".managed") || inc_string.to_s == "managed"
          # don't titleize tag name, need it to lookup later to get description by tag name
          field_value = friendly_model_name(rpt.db + "." + inc_string.to_s) + col.split(".").last
        else
          field_value = friendly_model_name(rpt.db + "." + inc_string.to_s) +
                        Dictionary.gettext(col.split(".").last.split("__").first, :type => :column, :notfound => :titleize)
        end
      end

      if field_key.include?("__")                           # Check for calculated pivot column
        field_key1, calc_typ = field_key.split("__")
        pivot_cols[field_key1] ||= []
        pivot_cols[field_key1] << calc_typ.to_sym
        pivot_cols[field_key1].sort!                          # Sort the array
        fields.push([field_value, field_key1]) unless fields.include?([field_value, field_key1]) # Add original col to fields array
      else
        fields.push([field_value, field_key])               # Add to fields array
      end

      # Create the groupby keys if groupby array is present
      if rpt.rpt_options &&
         rpt.rpt_options[:pivot] &&
         rpt.rpt_options[:pivot][:group_cols] &&
         rpt.rpt_options[:pivot][:group_cols].kind_of?(Array)
        if rpt.rpt_options[:pivot][:group_cols].length > 0
          @edit[:new][:pivotby1] = field_key if col == rpt.rpt_options[:pivot][:group_cols][0]
        end
        if rpt.rpt_options[:pivot][:group_cols].length > 1
          @edit[:new][:pivotby2] = field_key if col == rpt.rpt_options[:pivot][:group_cols][1]
        end
        if rpt.rpt_options[:pivot][:group_cols].length > 2
          @edit[:new][:pivotby3] = field_key if col == rpt.rpt_options[:pivot][:group_cols][2]
        end
      end

      # Create the sortby keys if sortby array is present
      if rpt.sortby.kind_of?(Array)
        if rpt.sortby.length > 0
          # If first sortby field as a break suffix, set up sortby1 with a suffix
          if MiqReport.is_break_suffix?(rpt.sortby[0].split("__")[1])
            sort1, suffix1 = rpt.sortby[0].split("__")  # Get sort field and suffix, if present
            @edit[:new][:sortby1] = field_key + (suffix1 ? "__#{suffix1}" : "") if col == sort1
          else  # Not a break suffix sort field, just copy the field name to sortby1
            @edit[:new][:sortby1] = field_key if col == rpt.sortby[0]
          end
        end
        if rpt.sortby.length > 1
          if MiqReport.is_break_suffix?(rpt.sortby[1].split("__")[1])
            sort2, suffix2 = rpt.sortby[1].split("__")  # Get sort field and suffix, if present
            @edit[:new][:sortby2] = field_key + (suffix2 ? "__#{suffix2}" : "") if col == sort2
          else  # Not a break suffix sort field, just copy the field name to sortby1
            @edit[:new][:sortby2] = field_key if col == rpt.sortby[1]
          end
        end
      end
      headers[field_key] = rpt.headers[idx] # Add col to the headers hash
      if field_key.include?("__")           # if this a pivot calc field?
        headers[field_key.split("__").first] = field_value  # Save the original field key as well
      end
      col_formats[field_key] = rpt.col_formats[idx] # Add col to the headers hash
    end

    # Remove the non-cost and owner columns from the arrays for Chargeback
    if Chargeback.db_is_chargeback?(rpt.db)
      f_len = fields.length
      for f_idx in 1..f_len # Go thru fields in reverse
        f_key = fields[f_len - f_idx].last
        next if f_key.ends_with?(*CHARGEBACK_ALLOWED_FIELD_SUFFIXES)
        headers.delete(f_key)
        col_formats.delete(f_key)
        fields.delete_at(f_len - f_idx)
      end
    end

    @edit[:new][:fields] = fields
    @edit[:new][:headers] = headers
    @edit[:new][:col_formats] = col_formats
    @edit[:pivot_cols] = pivot_cols
    build_field_order
  end

  # Create the field_order hash from the fields and pivot_cols structures
  def build_field_order
    @edit[:new][:field_order] = []
    @edit[:new][:fields].each do |f|
      if @edit[:new][:pivotby1] != NOTHING_STRING && # If we are doing pivoting and
         @edit[:pivot_cols].key?(f.last)             # this is a pivot calc column
        MiqReport::PIVOTS.each do |c|
          calc_typ = c.first
          @edit[:new][:field_order].push([f.first + " (#{calc_typ.to_s.titleize})", f.last + "__" + calc_typ.to_s]) if @edit[:pivot_cols][f.last].include?(calc_typ)
        end
      else
        @edit[:new][:field_order].push(f)
      end
    end
  end

  # Build the full includes string by finding the column in the includes hash
  def find_includes(col, includes)
    tables = col.split(".")[0..-2]
    field = col.split(".").last

    table = tables.first

    # Does this level include have the table name and does columns have the field name?
    if includes[table] && includes[table]["columns"] && includes[table]["columns"].include?(field)
      return table                                # Yes, return the table name
    end

    if includes[table] && includes[table]["include"]
      new_col = [tables[1..-1], field].flatten.join('.')
      # recursively search it for the table.col
      inc_table = find_includes(new_col, includes[table]["include"])
      return table + '.' + inc_table if inc_table
    end

    # Need to go to the next level
    includes.each_pair do |key, inc|              # Check each included table
      next unless inc["include"]                           # Does the included table have an include?

      inc_table = find_includes(col, inc["include"])  # Yes, recursively search it for the table.col
      return nil if inc_table.nil?                         # If it comes back nil, we never found it

      # Otherwise, return the table name + the included string
      return key + "." + inc_table
    end

    nil
  end

  def setnode_for_customreport
    @sb[:rpt_menu].each_with_index do |level1_nodes, i|
      if level1_nodes[0] == @sb[:grp_title]
        level1_nodes[1].each_with_index do |level2_nodes, k|
          # Check for the existence of the Custom folder in the Reports tree and
          # check if at least one report exists underneath it
          if level2_nodes[0].downcase == "custom" && level2_nodes[1].count > 1
            level2_nodes[1].each_with_index do |report|
              self.x_node = "xx-#{i}_xx-#{i}-#{k}_rep-#{to_cid(@rpt.id)}" if report == @rpt.name
            end
          end
        end
      end
    end
  end
end
