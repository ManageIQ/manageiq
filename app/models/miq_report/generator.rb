module MiqReport::Generator
  extend ActiveSupport::Concern

  include_concern 'Aggregation'
  include_concern 'Async'
  include_concern 'Html'
  include_concern 'Sorting'
  include_concern 'Trend'
  include_concern 'Utilization'

  DATE_TIME_BREAK_SUFFIXES = [
    [_("Hour"),              "hour"],
    [_("Day"),               "day"],
    [_("Week"),              "week"],
    [_("Month"),             "month"],
    [_("Quarter"),           "quarter"],
    [_("Year"),              "year"],
    [_("Hour of the Day"),   "hour_of_day"],
    [_("Day of the Week"),   "day_of_week"],
    [_("Day of the Month"),  "day_of_month"],
    [_("Week of the Year"),  "week_of_year"],
    [_("Month of the Year"), "month_of_year"]
  ].freeze

  module ClassMethods
    def date_time_break_suffixes
      DATE_TIME_BREAK_SUFFIXES
    end

    def get_col_break_suffixes(col)
      col_type = get_col_type(col)
      case col_type
      when :date
        date_time_break_suffixes.select { |_name, suffix| !suffix.to_s.starts_with?("hour") }
      when :datetime
        date_time_break_suffixes
      else
        []
      end
    end

    def all_break_suffixes
      date_time_break_suffixes.collect(&:last)
    end

    def is_break_suffix?(suffix)
      all_break_suffixes.include?(suffix)
    end

    def default_queue_timeout
      ::Settings.reporting.queue_timeout.to_i_with_method
    end
  end

  def col_to_expression_col(col)
    parts = col.split(".")
    if parts.length == 1
      table = db
    else
      table, col = parts[-2..-1]
    end
    "#{table2class(table)}-#{col}"
  end

  def table2class(table)
    @table2class ||= {}

    @table2class[table] ||= begin
      case table.to_sym
      when :ports, :nics, :storage_adapters
        "GuestDevice"
      when :"<compare>"
        self.class.name
      else
        ref = db_class.reflection_with_virtual(table.to_sym)
        ref ? ref.class_name : table.singularize.camelize
      end
    end

    @table2class[table]
  end

  def get_include_for_find
    (include_as_hash.presence || invent_includes).deep_merge(include_for_find || {}).presence
  end

  def invent_includes
    return {} unless col_order
    col_order.each_with_object({}) do |col, ret|
      next unless col.include?(".")
      *rels, _col = col.split(".")
      rels.inject(ret) { |h, rel| h[rel.to_sym] ||= {} } unless col =~ /managed\./
    end
  end

  # would like this format to go away
  # will go away when we drop build_reportable_data
  def invent_report_includes
    return {} unless col_order
    col_order.each_with_object({}) do |col, ret|
      next unless col.include?(".")
      *rels, column = col.split(".")
      if col !~ /managed\./ && col !~ /virtual_custom/
        (rels.inject(ret) { |h, rel| h[rel] ||= {} }["columns"] ||= []) << column
      end
    end
  end

  def include_as_hash(includes = include, klass = db_class, klass_cols = cols)
    result = {}
    if klass_cols && klass && klass.respond_to?(:virtual_attribute?)
      klass_cols.each do |c|
        result[c.to_sym] = {} if klass.virtual_attribute?(c) && !klass.attribute_supported_by_sql?(c)
      end
    end

    if includes.kind_of?(Hash)
      includes.each do |k, v|
        k = k.to_sym
        if k == :managed
          result[:tags] = {}
        else
          assoc_reflection = klass.reflect_on_association(k)
          assoc_klass = (assoc_reflection.options[:polymorphic] ? k : assoc_reflection.klass) if assoc_reflection

          result[k] = include_as_hash(v && v["include"], assoc_klass, v && v["columns"])
        end
      end
    elsif includes.kind_of?(Array)
      includes.each { |i| result[i.to_sym] = {} }
    end

    result
  end

  def queue_generate_table(options = {})
    options[:userid] ||= "system"
    options[:mode] ||= "async"
    options[:report_source] ||= "Requested by user"

    sync = options.delete(:report_sync) || ::Settings.product.report_sync

    task = MiqTask.create(:name => "Generate Report: '#{name}'", :userid => options[:userid])

    report_result = MiqReportResult.create(
      :name          => title,
      :userid        => options[:userid],
      :report_source => options[:report_source],
      :db            => db,
      :miq_report_id => id,
      :miq_task_id   => task.id
    )

    AuditEvent.success(
      :event        => "generate_table",
      :target_class => self.class.base_class.name,
      :target_id    => id,
      :userid       => options[:userid],
      :message      => "#{task.name}, successfully initiated"
    )

    task.update_status("Queued", "Ok", "Task has been queued")

    if sync
      _async_generate_table(task.id, options)
    else
      MiqQueue.submit_job(
        :service     => "reporting",
        :class_name  => self.class.name,
        :instance_id => id,
        :method_name => "_async_generate_table",
        :args        => [task.id, options],
        :msg_timeout => queue_timeout
      )
    end

    report_result.id
  end

  def generate_table(options = {})
    if options[:user]
      User.with_user(options[:user]) { _generate_table(options) }
    elsif options[:userid]
      userid = MiqReportResult.parse_userid(options[:userid])
      user = User.find_by_userid(userid)
      User.with_user(user, userid) { _generate_table(options) }
    else
      _generate_table(options)
    end
  end

  def _generate_table(options = {})
    return build_table_from_report(options) if db == self.class.name # Build table based on data from passed in report object
    _generate_table_prep

    results = if custom_results_method
                generate_custom_method_results(options)
              elsif performance
                generate_performance_results(options)
              elsif interval == 'daily' && db_klass <= MetricRollup
                generate_daily_metric_rollup_results(options)
              elsif interval
                generate_interval_metric_results(options)
              else
                generate_basic_results(options)
              end

    if db_options && db_options[:long_term_averages] && results.first.kind_of?(MetricRollup)
      # Calculate long_term_averages and save in extras
      extras[:long_term_averages] = Metric::LongTermAverages.get_averages_over_time_period(results.first.resource, db_options[:long_term_averages].merge(:ext_options => ext_options))
    end

    build_apply_time_profile(results)
    build_table(results, db, options)
  end

  def generate_custom_method_results(options = {})
    if db_klass.respond_to?(custom_results_method)
      # Use custom method in DB class to get report results if defined
      results, ext = db_klass.send(custom_results_method, db_options[:options].merge(:userid      => options[:userid],
                                                                                     :ext_options => ext_options,
                                                                                     :report_cols => cols))
    elsif respond_to?(custom_results_method)
      # Use custom method in MiqReport class to get report results if defined
      results, ext = send(custom_results_method, options)
    else
      raise _("Unsupported report type '%{type}'") % {:type => db_options[:rpt_type]}
    end
    # TODO: results = results.select(only_cols)
    extras.merge!(ext) if ext && ext.kind_of?(Hash)
    results
  end

  # Original C&U charts breakdown by tags
  def generate_performance_results(options = {})
    if performance[:group_by_category] && performance[:interval_name]
      results, extras[:interval] = db_class.vms_by_category(performance)
    else
      results, extras[:group_by_tag_cols], extras[:group_by_tags] = db_class.group_by_tags(
        db_class.find_entries(ext_options).where(where_clause).where(options[:where_clause]),
        :category  => performance[:group_by_category],
        :cat_model => options[:cat_model],
        :include   => get_include_for_find
      )
      build_correlate_tag_cols
    end
    results
  end

  # Ad-hoc daily performance reports
  #   Daily for: Performance - Clusters...
  def generate_daily_metric_rollup_results(options = {})
    unless conditions.nil?
      conditions.preprocess_options = {:vim_performance_daily_adhoc => (time_profile && time_profile.rollup_daily_metrics)}
      exp_sql, exp_includes = conditions.to_sql
      # only_cols += conditions.columns_for_sql # Add cols references in expression to ensure they are present for evaluation
    end

    time_range = Metric::Helper.time_range_from_offset(interval, db_options[:start_offset], db_options[:end_offset], tz)
    # TODO: add .select(only_cols)
    db_includes = get_include_for_find
    results = Metric::Helper.find_for_interval_name('daily', time_profile || tz, db_klass)
                            .where(where_clause).where(exp_sql)
                            .where(options[:where_clause])
                            .where(:timestamp => time_range)
                            .includes(db_includes)
                            .references(db_includes)
                            .includes(exp_includes || [])
                            .limit(options[:limit])
    results = Rbac.filtered(results, :class        => db,
                                     :filter       => conditions,
                                     :userid       => options[:userid],
                                     :miq_group_id => options[:miq_group_id])
    Metric::Helper.remove_duplicate_timestamps(results)
  end

  # Ad-hoc performance reports
  def generate_interval_metric_results(options = {})
    time_range = Metric::Helper.time_range_from_offset(interval, db_options[:start_offset], db_options[:end_offset])

    # Only build where clause from expression for hourly report. It will not work properly for daily because many values are rolled up from hourly.
    exp_sql, exp_includes = conditions.to_sql(tz) unless conditions.nil? || db_klass.respond_to?(:instances_are_derived?)

    results = db_klass.with_interval_and_time_range(interval, time_range)
                      .where(where_clause)
                      .where(options[:where_clause])
                      .where(exp_sql)
                      .includes(get_include_for_find)
                      .includes(exp_includes || [])
                      .limit(options[:limit])

    results = Rbac.filtered(results, :class        => db,
                                     :filter       => conditions,
                                     :userid       => options[:userid],
                                     :miq_group_id => options[:miq_group_id])
    Metric::Helper.remove_duplicate_timestamps(results)
  end

  # Basic report
  # Daily and Hourly for: C&U main reports go through here too
  def generate_basic_results(options = {})
    # TODO: need to enhance only_cols to better support virtual columns
    # only_cols += conditions.columns_for_sql if conditions # Add cols references in expression to ensure they are present for evaluation
    # NOTE: using search to get user property "managed", otherwise this is overkill
    targets = db_class
    targets = db_class.find_entries(ext_options) if targets.respond_to?(:find_entries)
    # TODO: add once only_cols is fixed
    # targets = targets.select(only_cols)
    where_clause = MiqExpression.merge_where_clauses(self.where_clause, options[:where_clause])

    # Remove custom_attributes as part of the `includes` if all of them exist
    # in the select statement
    if all_custom_attributes_are_virtual_sql_attributes?
      remove_loading_relations_for_virtual_custom_attributes
    end

    rbac_opts = options.merge(
      :targets          => targets,
      :filter           => conditions,
      :include_for_find => get_include_for_find,
      :where_clause     => where_clause,
      :skip_counts      => true
    )

    ## add in virtual attributes that can be calculated from sql
    rbac_opts[:extra_cols] = va_sql_cols unless va_sql_cols.blank?

    results, attrs = Rbac.search(rbac_opts)
    results = Metric::Helper.remove_duplicate_timestamps(results)
    results = BottleneckEvent.remove_duplicate_find_results(results) if db == "BottleneckEvent"
    @user_categories = attrs[:user_filters]["managed"]
    results
  end

  def build_create_results(options, taskid = nil)
    ts = Time.now.utc
    attrs = {
      :name             => title,
      :userid           => options[:userid],
      :report_source    => options[:report_source],
      :db               => db,
      :last_run_on      => ts,
      :last_accessed_on => ts,
      :miq_report_id    => id,
      :miq_group_id     => options[:miq_group_id]
    }

    _log.info("Creating report results with hash: [#{attrs.inspect}]")
    res   = MiqReportResult.find_by_miq_task_id(taskid) unless taskid.nil?
    res ||= MiqReportResult.find_by_userid(options[:userid]) if options[:userid].include?("|") # replace results if adhoc (<userid>|<session_id|<mode>) user report
    res ||= MiqReportResult.new
    res.attributes = attrs

    res.report_results = self

    curr_tz = Time.zone # Save current time zone setting
    userid = options[:userid].split("|").first if options[:userid]
    user = User.find_by_userid(userid) if userid

    # TODO: user is nil from MiqWidget#generate_report_result due to passing the username as the second part of :userid, such as widget_id_735|admin...
    # Looks like widget generation for a user doesn't expect multiple timezones, could be an issue with MiqGroups.
    timezone = options[:timezone]
    timezone ||= user.respond_to?(:get_timezone) ? user.get_timezone : User.server_timezone

    Time.zone = timezone

    html_rows = build_html_rows

    Time.zone = curr_tz # Restore current time zone setting

    res.report_html = html_rows
    self.extras ||= {}
    self.extras[:total_html_rows] = html_rows.length

    append_user_filters_to_title(user)

    report = dup
    report.table = nil
    res.report = report
    res.save
    _log.info("Finished creating report result with id [#{res.id}] for report id: [#{id}], name: [#{name}]")

    res
  end

  def build_table(data, db, options = {})
    data = data.to_a
    objs = data[0] && data[0].kind_of?(Integer) ? db_klass.where(:id => data) : data.compact

    remove_loading_relations_for_virtual_custom_attributes

    # Add resource columns to performance reports cols and col_order arrays for widget click thru support
    if db_klass.to_s.ends_with?("Performance")
      res_cols = ['resource_name', 'resource_type', 'resource_id']
      self.cols = (cols + res_cols).uniq
      orig_col_order = col_order.dup
      self.col_order = (col_order + res_cols).uniq
    end

    only_cols = options[:only] || cols_for_report(['id'])
    self.col_order = cols_for_report if col_order.blank?

    build_trend_data(objs)
    build_trend_limits(objs)

    # Add missing timestamps after trend calculation to prevent timestamp adjustment for added timestamps.
    objs = build_add_missing_timestamps(objs)

    data = build_includes(objs)
    inc = include.presence || invent_report_includes
    result = data.collect do |entry|
      build_reportable_data(entry, {:only => only_cols, "include" => inc}, nil)
    end.flatten

    if rpt_options && rpt_options[:pivot]
      result = build_pivot(result)
      column_names = col_order
    else
      column_names = only_cols
    end
    result = build_apply_display_filter(result) unless display_filter.nil?

    @table = Ruport::Data::Table.new(:data => result, :column_names => column_names)
    @table.reorder(column_names) unless @table.data.empty?

    # Remove any resource columns that were added earlier to col_order so they won't appear in the report
    col_order.delete_if { |c| res_cols.include?(c) && !orig_col_order.include?(c) } if res_cols

    build_sort_table unless options[:no_sort]

    if options[:limit]
      options[:offset] ||= 0
      self.extras[:target_ids_for_paging] = @table.data.collect { |d| d["id"] } # Save ids of targets, since we have then all, to avoid going back to SQL for the next page
      @table = @table.sub_table(@table.column_names, options[:offset]..options[:offset] + options[:limit] - 1)
    end

    build_subtotals
  end

  def build_table_from_report(options = {})
    unless db_options && db_options[:report]
      raise _("No %{class_name} object provided") % {:class_name => self.class.name}
    end
    unless db_options[:report].kind_of?(self.class)
      raise _("DB option :report must be a %{class_name} object") % {:class_name => self.class.name}
    end

    result = generate_rows_from_data(get_data_from_report(db_options[:report]))

    self.cols ||= []
    only_cols = options[:only] || cols_for_report(generate_cols)
    column_names = result.empty? ? self.cols : result.first.keys
    @table = Ruport::Data::Table.new(:data => result, :column_names => column_names)
    @table.reorder(only_cols) unless @table.data.empty?

    build_sort_table
  end

  def get_data_from_report(rpt)
    raise _("Report table is nil") if rpt.table.nil?

    if db_options[:row_col] && db_options[:row_val]
      rpt.table.find_all { |d| d.data.key?(db_options[:row_col]) && (d.data[db_options[:row_col]] == db_options[:row_val]) }.collect(&:data)
    else
      rpt.table.collect(&:data)
    end
  end

  def generate_rows_from_data(data)
    data.inject([]) do |arr, d|
      generate_rows.each do |gen_row|
        row = {}
        gen_row.each_with_index do |col_def, col_idx|
          new_col_name = generate_cols[col_idx]
          row[new_col_name] = generate_col_from_data(col_def, d)
        end
        arr << row
      end
      arr
    end
  end

  def generate_col_from_data(col_def, data)
    if col_def.kind_of?(Hash)
      unless data.key?(col_def[:col_name])
        raise _("Column '%{name} does not exist in data") % {:name => col_def[:col_name]}
      end
      return col_def.key?(:function) ? apply_col_function(col_def, data) : data[col_def[:col_name]]
    else
      return col_def
    end
  end

  def apply_col_function(col_def, data)
    case col_def[:function]
    when 'percent_of_col'
      unless data.key?(col_def[:col_name])
        raise _("Column '%{name} does not exist in data") % {:name => gen_row[:col_name]}
      end
      unless data.key?(col_def[:pct_col_name])
        raise _("Column '%{name} does not exist in data") % {:name => gen_row[:pct_col_name]}
      end
      col_val = data[col_def[:col_name]] || 0
      pct_val = data[col_def[:pct_col_name]] || 0
      return pct_val == 0 ? 0 : (col_val / pct_val * 100.0)
    else
      raise _("Column function '%{name}' not supported") % {:name => col_def[:function]}
    end
  end

  def build_correlate_tag_cols
    tags2desc = {}
    arr = self.cols.inject([]) do |a, c|
      self.extras[:group_by_tag_cols].each do |tc|
        tag = tc[(c.length + 1)..-1]
        if tc.starts_with?(c)
          unless tags2desc.key?(tag)
            if tag == "_none_"
              tags2desc[tag] = "[None]"
            else
              entry = Classification.find_by_name([performance[:group_by_category], tag].join("/"))
              tags2desc[tag] = entry.nil? ? tag.titleize : entry.description
            end
          end
          a << [tc, tags2desc[tag]]
        end
      end
      a
    end
    arr.sort! { |a, b| a[1] <=> b[1] }
    while arr.first[1] == "[None]"
      arr.push(arr.shift)
    end unless arr.blank? || (arr.first[1] == "[None]" && arr.last[1] == "[None]")
    arr.each do |c, h|
      self.cols.push(c)
      col_order.push(c)
      headers.push(h)
    end

    tarr = Array(tags2desc).sort_by { |t| t[1] }
    while tarr.first[1] == "[None]"
      tarr.push(tarr.shift)
    end unless tarr.blank? || (tarr.first[1] == "[None]" && tarr.last[1] == "[None]")
    self.extras[:group_by_tags] = tarr.collect { |a| a[0] }
    self.extras[:group_by_tag_descriptions] = tarr.collect { |a| a[1] }
  end

  def build_add_missing_timestamps(recs)
    return recs unless !recs.empty? && (recs.first.kind_of?(Metric) || recs.first.kind_of?(MetricRollup))
    return recs if db_options && db_options[:calc_avgs_by] && db_options[:calc_avgs_by] != "time_interval" # Only fill in missing timestamps if averages are requested to be based on time

    base_cols = Metric::BASE_COLS - ["id"]
    int = recs.first.capture_interval_name == 'daily' ? 1.day.to_i : 1.hour.to_i
    klass = recs.first.class
    last_rec = nil

    results = recs.sort_by { |r| [r.resource_type, r.resource_id.to_s, r.timestamp.iso8601] }.inject([]) do |arr, rec|
      last_rec ||= rec
      while (rec.timestamp - last_rec.timestamp) > int
        base_attrs = last_rec.attributes.reject { |k, _v| !base_cols.include?(k) }
        last_rec = klass.new(base_attrs.merge(:timestamp => (last_rec.timestamp + int)))
        last_rec.inside_time_profile = false if last_rec.respond_to?(:inside_time_profile)
        arr << last_rec
      end
      arr << rec
      last_rec = rec
      arr
    end
    results
  end

  def build_apply_time_profile(results)
    return unless time_profile
    # Apply time profile if one was provided
    results.each { |rec| rec.apply_time_profile(time_profile) if rec.respond_to?(:apply_time_profile) }
  end

  def build_apply_display_filter(results)
    return results if display_filter.nil?

    if display_filter.kind_of?(MiqExpression)
      display_filter.context_type = "hash" # Tell MiqExpression that the context objects are hashes
      results.find_all { |h| display_filter.evaluate(h) }
    elsif display_filter.kind_of?(Proc)
      results.select(&display_filter)
    elsif display_filter.kind_of?(Hash)
      op  = display_filter[:operator]
      fld = display_filter[:field].to_s
      val = display_filter[:value]
      results.select do |r|
        case op
        when "="  then (r[fld] == val)
        when "!=" then (r[fld] != val)
        when "<"  then (r[fld] < val)
        when "<=" then (r[fld] <= val)
        when ">"  then (r[fld] > val)
        when ">=" then (r[fld] >= val)
        else
          false
        end
      end
    end
  end

  def get_group_val(row, keys)
    keys.inject([]) { |a, k| a << row[k] }.join("__")
  end

  def process_group_break(gid, group, totals, result)
    result[gid] = group
    totals[:count] += group[:count]
    process_totals(group)
  end

  def build_pivot(data)
    return data unless rpt_options && rpt_options.key?(:pivot)
    return data if data.blank?

    # Build a tempory table so that ruport sorting can be used to sort data before summarizing pivot data
    column_names = (data.first.keys.collect(&:to_s) + col_order).uniq
    data = Ruport::Data::Table.new(:data => data, :column_names => column_names)
    data = sort_table(data, rpt_options[:pivot][:group_cols].collect(&:to_s), :order => :ascending)

    # build grouping options for subtotal
    options = col_order.inject({}) do |h, col|
      next(h) unless col.include?("__")

      c, g = col.split("__")
      h[c] ||= {}
      h[c][:grouping] ||= []
      h[c][:grouping] << g.to_sym
      h
    end

    group_key =  rpt_options[:pivot][:group_cols]
    data = generate_subtotals(data, group_key, options)
    data.inject([]) do |a, (k, v)|
      next(a) if k == :_total_
      row = col_order.inject({}) do |h, col|
        if col.include?("__")
          c, g = col.split("__")
          h[col] = v[g.to_sym][c]
        else
          h[col] = v[:row][col]
        end
        h
      end
      a << row
    end
  end

  # the columns that are needed for this report.
  # there may be some columns that are used to derive columns,
  # so we currently include '*'
  def cols_for_report(extra_cols = [])
    ((cols || []) + (col_order || []) + (extra_cols || []) + build_cols_from_include(include)).uniq
  end

  def build_cols_from_include(hash, parent_association = nil)
    return [] if hash.blank?
    hash.inject([]) do |a, (k, v)|
      full_path = get_full_path(parent_association, k)
      v["columns"].each { |c| a << get_full_path(full_path, c) } if v.key?("columns")
      a += (build_cols_from_include(v["include"], full_path) || []) if v.key?("include")
      a
    end
  end

  def build_includes(objs)
    results = []

    inc = include.presence || invent_report_includes
    objs.each do |obj|
      entry = {:obj => obj}
      build_search_includes(obj, entry, inc) if inc
      results.push(entry)
    end

    results
  end

  def build_search_includes(obj, entry, includes)
    includes.each_key do |assoc|
      next unless obj.respond_to?(assoc)

      assoc_objects = [obj.send(assoc)].flatten.compact

      entry[assoc.to_sym] = assoc_objects.collect do |rec|
        new_entry = {:obj => rec}
        build_search_includes(rec, new_entry, includes[assoc]["include"]) if includes[assoc]["include"]
        new_entry
      end
    end
  end

  # simplify to use col_sort_order. "include" won't be necessary)
  def build_reportable_data(entry, options, parent_association)
    rec = entry[:obj]
    data_records = [build_get_attributes_with_options(rec, options)]
    data_records = build_add_includes(data_records, entry, options["include"], parent_association) if options["include"]
    data_records
  end

  def build_get_attributes_with_options(rec, options = {})
    only_or_except =
      if options[:only] || options[:except]
        {:only => options[:only], :except => options[:except]}
      end
    return {} unless only_or_except
    attrs = {}
    options[:only].each do |a|
      if self.class.is_trend_column?(a)
        attrs[a] = build_calculate_trend_point(rec, a)
      else
        attrs[a] = rec.send(a) if rec.respond_to?(a)
      end
    end
    attrs = attrs.inject({}) do |h, (k, v)|
      h["#{options[:qualify_attribute_names]}.#{k}"] = v
      h
    end if options[:qualify_attribute_names]
    attrs
  end

  def build_add_includes(data_records, entry, includes, parent_association)
    include_has_options = includes.kind_of?(Hash)
    associations = include_has_options ? includes.keys : Array(includes)

    associations.each do |association|
      existing_records = data_records.dup
      data_records = []
      full_path = get_full_path(parent_association, association)
      if include_has_options
        assoc_options = includes[association].merge(:qualify_attribute_names => full_path,
                                                    :only                    => includes[association]["columns"])
      else
        assoc_options = {:qualify_attribute_names => full_path, :only => includes[association]["columns"]}
      end

      if association == "categories" || association == "managed"
        association_objects = []
        assochash = {}
        @descriptions_by_tag_id ||= Classification.where("parent_id != 0").each_with_object({}) do |c, h|
          h[c.tag_id] = c.description
        end

        assoc_options[:only].each do |c|
          entarr = []
          entry[:obj].tags.each do |t|
            next unless t.name.starts_with?("/managed/#{c}/")
            next unless @descriptions_by_tag_id.key?(t.id)
            entarr << @descriptions_by_tag_id[t.id]
          end
          assochash[full_path + "." + c] = entarr unless entarr.empty?
        end
        # join the the category data together
        longest = 0
        idx = 0
        assochash.each_key { |k| longest = assochash[k].length if assochash[k].length > longest }
        longest.times do
          nh = {}
          assochash.each_key { |k| nh[k] = assochash[k][idx].nil? ? assochash[k].last : assochash[k][idx] }
          association_objects.push(nh)
          idx += 1
        end
      else
        association_objects = entry[association.to_sym]
      end

      existing_records.each do |existing_record|
        if association_objects.empty?
          data_records << existing_record
        else
          association_objects.each do |obj|
            if association == "categories" || association == "managed"
              association_records = [obj]
            else
              association_records = build_reportable_data(obj, assoc_options, full_path)
            end
            association_records.each do |assoc_record|
              data_records << existing_record.merge(assoc_record)
            end
          end
        end
      end
    end
    data_records
  end

  def queue_report_result(options, res_opts)
    options[:userid] ||= "system"
    _log.info("Adding generate report task to the message queue...")
    task = MiqTask.create(:name => "Generate Report: '#{name}'", :userid => options[:userid])

    MiqQueue.submit_job(
      :service     => "reporting",
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "build_report_result",
      :msg_timeout => queue_timeout,
      :args        => [task.id, options, res_opts]
    )
    AuditEvent.success(:event => "generate_table", :target_class => self.class.base_class.name, :target_id => id, :userid => options[:userid], :message => "#{task.name}, successfully initiated")
    task.update_status("Queued", "Ok", "Task has been queued")

    _log.info("Finished adding generate report task with id [#{task.id}] to the message queue")
    task.id
  end

  def build_report_result(taskid, options, res_opts = {})
    task = MiqTask.find(taskid)

    # Generate the table only if the task does not already contain a MiqReport object
    if task.task_results.blank?
      _log.info("Generating report table with taskid [#{taskid}] and options [#{options.inspect}]")
      _async_generate_table(taskid, options.merge(:mode => "schedule", :report_source => res_opts[:source]))

      # Reload the task after the _async_generate_table has updated it
      task.reload
      if !task.results_ready?
        _log.warn("Generating report table with taskid [#{taskid}]... Failed to complete, '#{task.message}'")
        return
      else
        _log.info("Generating report table with taskid [#{taskid}]... Complete")
      end
    end

    res_last_run_on  = Time.now.utc

    # If a scheduler :at time was provided, convert that to a Time object, otherwise use the current time
    if res_opts[:at]
      unless res_opts[:at].kind_of?(Numeric)
        raise _("Expected scheduled time 'at' to be 'numeric', received '%{type}'") % {:type => res_opts[:at].class}
      end
      at = Time.at(res_opts[:at]).utc
    else
      at = res_last_run_on
    end

    res = task.miq_report_result
    nh = {:miq_task_id => taskid, :scheduled_on => at}
    _log.info("Updating report results with hash: [#{nh.inspect}]")
    res.update_attributes(nh)
    _log.info("Finished creating report result with id [#{res.id}] for report id: [#{id}], name: [#{name}]")

    notify_user_of_report(res_last_run_on, res, options) if options[:send_email]

    # Remove the table in the task_results since we now have it in the report_results
    task.task_results = nil
    task.save
    res
  end

  def table_has_records?
    !table.empty?
  end

  def queue_timeout
    ((rpt_options || {})[:queue_timeout] || self.class.default_queue_timeout).to_i_with_method
  end

  def queue_timeout=(value)
    self.rpt_options ||= {}
    self.rpt_options[:queue_timeout] = value
  end

  #####################################################

  def append_to_title!(title_suffix)
    self.title += title_suffix
  end

  def append_user_filters_to_title(user)
    return unless user && user.has_filters?
    self.append_to_title!(" (filtered for #{user.name})")
  end

  def get_time_zone(default_tz = nil)
    time_profile ? time_profile.tz || tz || default_tz : tz || default_tz
  end

  private

  def get_full_path(parent, child)
    if parent
      "#{parent}.#{child}"
    else
      child.to_s
    end
  end

  # Preps the current instance and db class for building a report
  def _generate_table_prep
    # Make sure the db_klass has the custom_attribute definitions defined for
    # the report being built.
    load_custom_attributes

    # Default time zone in profile to report time zone
    time_profile.tz ||= tz if time_profile
    self.ext_options  = {:tz => tz, :time_profile => time_profile}

    # TODO: these columns need to be converted to real SQL columns
    # only_cols = cols

    self.extras ||= {}
  end

  def interval
    @interval ||= db_options.present? && db_options[:interval]
  end

  def custom_results_method
    @custom_results_method ||= db_options && db_options[:rpt_type] ? "build_results_for_report_#{db_options[:rpt_type]}" : nil
  end
end
