module MiqReport::Generator
  extend ActiveSupport::Concern

  include_concern 'Aggregation'
  include_concern 'Async'
  include_concern 'Html'
  include_concern 'Sorting'
  include_concern 'Trend'
  include_concern 'Utilization'

  DATE_TIME_BREAK_SUFFIXES = [
    ["Hour",              "hour"],
    ["Day",               "day"],
    ["Week",              "week"],
    ["Month",             "month"],
    ["Quarter",           "quarter"],
    ["Year",              "year"],
    ["Hour of the Day",   "hour_of_day"],
    ["Day of the Week",   "day_of_week"],
    ["Day of the Month",  "day_of_month"],
    ["Week of the Year",  "week_of_year"],
    ["Month of the Year", "month_of_year"]
  ].freeze

  module ClassMethods

    def date_time_break_suffixes
      DATE_TIME_BREAK_SUFFIXES
    end

    def get_col_break_suffixes(col)
      col_type = self.get_col_type(col)
      return case col_type
      when :date
        date_time_break_suffixes.select {|name,suffix| !suffix.to_s.starts_with?("hour")}
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
      self.all_break_suffixes.include?(suffix)
    end

    def default_queue_timeout
      value = VMDB::Config.new("vmdb").config.fetch_path(:reporting, :queue_timeout) || 3600
      return value.to_i_with_method
    end
  end

  def col_to_expression_col(col)
    parts = col.split(".")
    if parts.length == 1
      table = self.db
    else
      table, col = parts[-2..-1]
    end
    return "#{self.table2class(table)}-#{col}"
  end

  def table2class(table)
    @table2class ||= {}

    @table2class[table] ||= begin
      case table.to_sym
      # when :users, :groups
      #   "Account"
      when :ports, :nics, :storage_adapters
        "GuestDevice"
      # when :system_services, :win32_services, :kernel_drivers, :filesystem_drivers, :linux_initprocesses, :host_services
      #   "SystemService"
      when :"<compare>"
        self.class.name
      else
        ref = db_class.reflection_with_virtual(table.to_sym)
        ref ? ref.class_name : table.singularize.camelize
      end
    end

    @table2class[table]
  end

  def get_include_for_find(includes, klass=nil)
    if klass.nil?
      klass = self.db_class
      result = {}
      self.cols.each { |c| result.merge!(c.to_sym => {}) if klass.virtual_column?(c) } if self.cols
    end

    if includes.is_a?(Hash)
      result ||= {}
      includes.each do |k,v|
        k = k.to_sym
        if k == :managed
          result.merge!(:tags => {})
        else
          assoc_reflection = klass.reflect_on_association(k)
          assoc_klass = assoc_reflection.nil? ? nil : (assoc_reflection.options[:polymorphic] ? k : assoc_reflection.klass)

          if v.nil? || v["include"].blank?
            result.merge!(k => {})
          else
            result.merge!(k => get_include_for_find(v["include"], assoc_klass)) if assoc_klass
          end

          v["columns"].each { |c| result[k].merge!(c.to_sym => {}) if assoc_klass.virtual_column?(c) } if assoc_klass && assoc_klass.respond_to?(:virtual_column?) && v["columns"]
        end
      end
    elsif includes.is_a?(Array)
      result ||= {}
      includes.each {|i| result.merge!(i.to_sym => {}) }
    end

    return result
  end

  def report
    @report ||= YAML.object_maker(MIQ_Report, self.attributes)
  end

  def queue_generate_table(options = {})
    options[:userid]        ||= "system"
    options[:mode]          ||= "async"
    options[:report_source] ||= "Requested by user"

    sync = VMDB::Config.new("vmdb").config[:product][:report_sync]

    task = MiqTask.create(:name => "Generate Report: '#{self.name}'")

    report_result = MiqReportResult.create(
                      :name             => self.title,
                      :userid           => options[:userid],
                      :report_source    => options[:report_source],
                      :db               => self.db,
                      :miq_report_id    => self.id,
                      :miq_task_id      => task.id
                    )

    AuditEvent.success(
      :event        => "generate_table",
      :target_class => self.class.base_class.name,
      :target_id    => self.id,
      :userid       => options[:userid],
      :message      => "#{task.name}, successfully initiated"
    )

    task.update_status("Queued", "Ok", "Task has been queued")

    if sync
      _async_generate_table(task.id, options)
    else
      MiqQueue.put(
        :queue_name   => "reporting",
        :class_name   => self.class.name,
        :instance_id  => self.id,
        :method_name  => "_async_generate_table",
        :args         => [task.id, options],
        :msg_timeout  => self.queue_timeout
      )
    end

    return report_result.id
  end

  def generate_table(options = {})
    if options[:userid]
      User.with_userid(MiqReportResult.parse_userid(options[:userid])) { _generate_table(options) }
    else
      _generate_table(options)
    end
  end

  def _generate_table(options = {})
    return self.build_table_from_report(options) if self.db == self.class.name # Build table based on data from passed in report object

    klass = db.is_a?(Class) ? db : Object.const_get(db)
    custom_results_method = (db_options && db_options[:rpt_type]) ? "build_results_for_report_#{db_options[:rpt_type]}" : nil

    includes = self.get_include_for_find(self.include)
    where_clause = MiqExpression.merge_where_clauses(self.where_clause, options[:where_clause])

    self.time_profile.tz ||= self.tz if self.time_profile # Default time zone in profile to report time zone
    ext_options = {:only_cols => self.cols, :tz => self.tz, :time_profile => self.time_profile}
    self.extras ||= {}

    if custom_results_method
      if klass.respond_to?(custom_results_method)
        # Use custom method in DB class to get report results if defined
        results, ext = klass.send(custom_results_method, db_options[:options].merge(:userid => options[:userid], :ext_options => ext_options))
      elsif self.respond_to?(custom_results_method)
        # Use custom method in MiqReport class to get report results if defined
        results, ext = self.send(custom_results_method, options)
      else
        raise "Unsupported report type '#{db_options[:rpt_type]}'"
      end
      self.extras.merge!(ext) if ext && ext.kind_of?(Hash)

    elsif self.performance
      # Original C&U charts breakdown by tags
      if self.performance[:group_by_category] && self.performance[:interval_name]
        results, self.extras[:interval]  = db_class.vms_by_category(self.performance)
        self.build_table(results, self.db, options)
      else
        results, self.extras[:group_by_tag_cols], self.extras[:group_by_tags] = db_class.find_and_group_by_tags(
          :where_clause => where_clause,
          :category => self.performance[:group_by_category],
          :cat_model => options[:cat_model],
          :ext_options => ext_options,
          :include => includes
        )
        self.build_correlate_tag_cols
      end

    elsif !self.db_options.blank? && self.db_options[:interval] == 'daily' && klass.is_or_subclass_of?(MetricRollup)
      # Ad-hoc daily performance reports
      #   Daily for: Performance - Clusters...
      associations = includes.is_a?(Hash) ? includes.keys : Array(includes)

      results = []

      unless self.conditions.nil?
        self.conditions.preprocess_options = {:vim_performance_daily_adhoc => (self.time_profile && self.time_profile.rollup_daily_metrics)}
        exp_sql, exp_includes = self.conditions.to_sql
        where_clause, includes = MiqExpression.merge_where_clauses_and_includes([where_clause, exp_sql], [includes, exp_includes])
        ext_options[:only_cols] += self.conditions.columns_for_sql # Add cols references in expression to ensure they are present for evaluation
      end

      start_time, end_time = Metric::Helper.get_time_range_from_offset(self.db_options[:start_offset], self.db_options[:end_offset], :tz => self.tz)
      time_range_cond = ["timestamp BETWEEN ? AND ?", start_time, end_time]
      results = VimPerformanceDaily.find(:all,
        :conditions  => klass.merge_conditions(where_clause, time_range_cond),
        :include     => includes,
        :limit       => options[:limit],
        :ext_options => ext_options.merge(:reflections => associations, :class => klass)
      )
      results, attrs = !results.empty? ? Rbac.search(:targets => results, :class => self.db, :filter => self.conditions, :results_format => :objects, :userid => options[:userid], :miq_group_id => options[:miq_group_id]) : [results, {}]
      results = Metric::Helper.remove_duplicate_timestamps(results)
    elsif !self.db_options.blank? && self.db_options.has_key?(:interval)
      # Ad-hoc performance reports

      start_time = Time.now.utc - self.db_options[:start_offset].seconds
      end_time   =  self.db_options[:end_offset].nil? ? Time.now.utc : Time.now.utc -  self.db_options[:end_offset].seconds

      # Only build where clause from expression for hourly report. It will not work properly for daily because many values are rolled up from hourly.
      exp_sql, exp_includes = self.conditions.to_sql(self.tz) unless self.conditions.nil? || klass.respond_to?(:instances_are_derived?)
      where_clause, includes = MiqExpression.merge_where_clauses_and_includes([where_clause, exp_sql], [includes, exp_includes])

      results = klass.find_all_by_interval_and_time_range(
        self.db_options[:interval],
        start_time,
        end_time,
        :all, :conditions => where_clause,
        :include => includes,
        :limit => options[:limit]
      )

      results, attrs = !results.empty? ? Rbac.search(:targets => results, :class => self.db, :filter => self.conditions, :results_format => :objects, :userid => options[:userid], :miq_group_id => options[:miq_group_id]) : [results, {}]
      results = Metric::Helper.remove_duplicate_timestamps(results)
    else
      # Basic report
      # Daily and Hourly for: C&U main reports go through here too
      ext_options[:only_cols] += self.conditions.columns_for_sql if self.conditions # Add cols references in expression to ensure they are present for evaluation
      results, attrs = Rbac.search(
        options.merge(
          :class            => self.db,
          :filter           => self.conditions,
          :include_for_find => includes,
          :where_clause     => where_clause,
          :results_format   => :objects,
          :ext_options      => ext_options
        )
      )
      results = Metric::Helper.remove_duplicate_timestamps(results)
      results = BottleneckEvent.remove_duplicate_find_results(results) if self.db == "BottleneckEvent"
      @user_categories = attrs[:user_filters]["managed"]
    end

    if self.db_options && self.db_options[:long_term_averages] && results.first.kind_of?(MetricRollup)
      # Calculate long_term_averages and save in extras
      self.extras[:long_term_averages] = Metric::LongTermAverages.get_averages_over_time_period(results.first.resource, self.db_options[:long_term_averages].merge(:ext_options => ext_options))
    end

    self.build_apply_time_profile(results)
    self.build_table(results, self.db, options)
  end

  def build_create_results(options, taskid = nil)
    ts = Time.now.utc
    attrs = {
      :name             => self.title,
      :userid           => options[:userid],
      :report_source    => options[:report_source],
      :db               => self.db,
      :last_run_on      => ts,
      :last_accessed_on => ts,
      :miq_report_id    => self.id
    }

    $log.info("MIQ(MiqReport-build_create_results) Creating report results with hash: [#{attrs.inspect}]")
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

    html_rows = self.build_html_rows

    Time.zone = curr_tz # Restore current time zone setting

    res.report_html = html_rows
    self.extras ||= {}
    self.extras[:total_html_rows] = html_rows.length

    self.append_user_filters_to_title(user)

    report = self.dup
    report.table = nil
    res.report = report
    res.save
    $log.info("MIQ(MiqReport-build_create_results) Finished creating report result with id [#{res.id}] for report id: [#{self.id}], name: [#{self.name}]")

    return res
  end

  def build_table(data, db, options={})
    klass = db.respond_to?(:constantize) ? db.constantize : db
    objs = data[0] && data[0].is_a?(Integer) ? klass.find_all_by_id(data) : data.compact

    # Add resource columns to performance reports cols and col_order arrays for widget click thru support
    if klass.to_s.ends_with?("Performance")
      res_cols = ['resource_name', 'resource_type','resource_id']
      self.cols = (self.cols + res_cols).uniq
      orig_col_order = self.col_order.dup
      self.col_order = (self.col_order + res_cols).uniq
    end

    only_cols = options[:only] || ((self.cols || []) + self.build_cols_from_include(self.include)).uniq + ['id']
    self.col_order = ((self.cols || []) + self.build_cols_from_include(self.include)).uniq if self.col_order.blank?

    self.build_trend_data(objs)
    self.build_trend_limits(objs)

    # Add missing timestamps after trend calculation to prevent timestamp adjustment for added timestamps.
    objs = self.build_add_missing_timestamps(objs)

    data = self.build_includes(objs)
    result = data.collect {|entry|
      self.build_reportable_data(entry, :only => only_cols, "include" => self.include)
    }.flatten

    if self.rpt_options && self.rpt_options[:pivot]
      result = self.build_pivot(result)
      column_names = self.col_order
    else
      column_names = only_cols
    end
    result = self.build_apply_display_filter(result) unless self.display_filter.nil?

    @table = Ruport::Data::Table.new(:data => result, :column_names => column_names)
    @table.reorder(column_names) unless @table.data.length == 0

    # Remove any resource columns that were added earlier to col_order so they won't appear in the report
    self.col_order.delete_if{|c| res_cols.include?(c) && !orig_col_order.include?(c)} if res_cols

    self.build_sort_table unless options[:no_sort]

    if options[:limit]
      options[:offset] ||= 0
      self.extras[:target_ids_for_paging] = @table.data.collect {|d| d["id"]} # Save ids of targets, since we have then all, to avoid going back to SQL for the next page
      @table = @table.sub_table(@table.column_names, options[:offset]..options[:offset] + options[:limit] - 1)
    end

    self.build_subtotals
  end

  def build_table_from_report(options = {})
    raise "No #{self.class.name} object provided" unless self.db_options && self.db_options[:report]
    raise "DB option :report must be a #{self.class.name} object" unless self.db_options[:report].kind_of?(self.class)

    result = self.generate_rows_from_data( self.get_data_from_report(self.db_options[:report]))

    self.cols ||= []
    only_cols = options[:only] || (self.cols + self.generate_cols + self.build_cols_from_include(self.include)).uniq
    column_names = result.empty? ? self.cols : result.first.keys
    @table = Ruport::Data::Table.new(:data => result, :column_names => column_names)
    @table.reorder(only_cols) unless @table.data.length == 0

    self.build_sort_table
  end

  def get_data_from_report(rpt)
    raise "Report table is nil" if rpt.table.nil?

    rpt_data = if self.db_options[:row_col] && self.db_options[:row_val]
      rpt.table.find_all {|d| d.data.has_key?(self.db_options[:row_col]) && (d.data[self.db_options[:row_col]] == self.db_options[:row_val])}.collect(&:data)
    else
      rpt.table.collect(&:data)
    end
  end

  def generate_rows_from_data(data)
    data.inject([]) do |arr,d|
      generate_rows.each do |gen_row|
        row = {}
        gen_row.each_with_index do |col_def, col_idx|
          new_col_name = generate_cols[col_idx]
          row[new_col_name] = self.generate_col_from_data(col_def, d)
        end
        arr << row
      end
      arr
    end
  end

  def generate_col_from_data(col_def, data)
    unless col_def.is_a?(Hash)
      return col_def
    else
      raise "Column '#{col_def[:col_name]} does not exist in data" unless data.has_key?(col_def[:col_name])
      return col_def.has_key?(:function) ? self.apply_col_function(col_def, data) : data[col_def[:col_name]]
    end
  end

  def apply_col_function(col_def, data)
    case col_def[:function]
    when 'percent_of_col'
      raise "Column '#{gen_row[:col_name]} does not exist in data" unless data.has_key?(col_def[:col_name])
      raise "Column '#{gen_row[:pct_col_name]} does not exist in data" unless data.has_key?(col_def[:pct_col_name])
      col_val = data[col_def[:col_name]] || 0
      pct_val = data[col_def[:pct_col_name]] || 0
      return pct_val == 0 ? 0 : (col_val / pct_val * 100.0)
    else
      raise "Column function '#{col_def[:function]}' not supported"
    end
  end


  def build_correlate_tag_cols
    tags2desc = {}
    arr = self.cols.inject([]) {|a, c|
      self.extras[:group_by_tag_cols].each {|tc|
        tag = tc[(c.length + 1)..-1]
        if tc.starts_with?(c)
          unless tags2desc.has_key?(tag)
            unless tag == "_none_"
              entry = Classification.find_by_name([self.performance[:group_by_category], tag].join("/"))
              tags2desc[tag] = entry.nil? ? tag.titleize : entry.description
            else
              tags2desc[tag] = "[None]"
            end
          end
          a << [tc, tags2desc[tag]]
        end
      }
      a
    }
    arr.sort!{|a,b| a[1] <=> b[1]}
    while arr.first[1] == "[None]"; arr.push(arr.shift); end unless arr.blank? || (arr.first[1] == "[None]" && arr.last[1] == "[None]")
    arr.each {|c, h| self.cols.push(c); self.col_order.push(c); self.headers.push(h)}

    tarr = Array(tags2desc).sort{|a,b| a[1] <=> b[1]}
    while tarr.first[1] == "[None]"; tarr.push(tarr.shift); end unless tarr.blank? || (tarr.first[1] == "[None]" && tarr.last[1] == "[None]")
    self.extras[:group_by_tags] = tarr.collect {|a| a[0]}
    self.extras[:group_by_tag_descriptions] = tarr.collect {|a| a[1]}
  end


  def build_add_missing_timestamps(recs)
    return recs unless !recs.empty? && (recs.first.kind_of?(Metric) || recs.first.kind_of?(MetricRollup))
    return recs if self.db_options && self.db_options[:calc_avgs_by] && self.db_options[:calc_avgs_by] != "time_interval" # Only fill in missing timestamps if averages are requested to be based on time

    base_cols = Metric::BASE_COLS - ["id"]
    int = recs.first.capture_interval_name == 'daily' ? 1.day.to_i : 1.hour.to_i
    klass = recs.first.class
    last_rec = nil

    results = recs.sort {|a,b| a.resource_type + a.resource_id.to_s + a.timestamp.iso8601 <=> b.resource_type + b.resource_id.to_s + b.timestamp.iso8601}.inject([]) do |arr, rec|
      last_rec ||= rec
      while (rec.timestamp - last_rec.timestamp) > int do
        base_attrs = last_rec.attributes.reject {|k,v| !base_cols.include?(k)}
        last_rec = klass.new(base_attrs.merge(:timestamp => (last_rec.timestamp + int)))
        # $log.info("XXX: Adding timestamp: [#{last_rec.timestamp}]")
        last_rec.inside_time_profile = false if last_rec.respond_to?(:inside_time_profile)
        arr << last_rec
      end
      arr << rec
      last_rec = rec
      arr
    end
    return results
  end

  def build_apply_time_profile(results)
    return unless self.time_profile
    # Apply time profile if one was provided
    results.each {|rec| rec.apply_time_profile(self.time_profile) if rec.respond_to?(:apply_time_profile)}
  end

  def build_apply_display_filter(results)
    return results if self.display_filter.nil?

    if self.display_filter.kind_of?(MiqExpression)
      self.display_filter.context_type = "hash" # Tell MiqExpression that the context objects are hashes
      results.find_all { |h| self.display_filter.evaluate(h) }
    elsif self.display_filter.kind_of?(Proc)
      results.select(&self.display_filter)
    elsif self.display_filter.kind_of?(Hash)
      op  = self.display_filter[:operator]
      fld = self.display_filter[:field].to_s
      val = self.display_filter[:value]
      results.select do |r|
        case op
        when "="  then (r[fld] == val)
        when "!=" then (r[fld] != val)
        when "<"  then (r[fld] <  val)
        when "<=" then (r[fld] <= val)
        when ">"  then (r[fld] >  val)
        when ">=" then (r[fld] >= val)
        else
          false
        end
      end
    end
  end

  def get_group_val(row, keys)
    keys.inject([]) {|a,k| a << row[k] }.join("__")
  end

  def process_group_break(gid, group, totals, result)
    result[gid] = group
    totals[:count] += group[:count]
    process_totals(group)
  end

  def build_pivot(data)
    return data unless self.rpt_options && self.rpt_options.has_key?(:pivot)
    return data if data.blank?

    # Build a tempory table so that ruport sorting can be used to sort data before summarizing pivot data
    column_names = (data.first.keys.collect(&:to_s) + self.col_order).uniq
    data = Ruport::Data::Table.new(:data => data, :column_names => column_names)
    data = self.sort_table(data, self.rpt_options[:pivot][:group_cols].collect(&:to_s), :order => :ascending)

    # build grouping options for subtotal
    options = self.col_order.inject({}) do |h,col|
      next(h) unless col.include?("__")

      c, g = col.split("__")
      h[c] ||= {}
      h[c][:grouping] ||= []
      h[c][:grouping] << g.to_sym
      h
    end

    group_key =  self.rpt_options[:pivot][:group_cols]
    data = generate_subtotals(data, group_key, options)
    data = data.inject([]) do |a,(k,v)|
      next(a) if k == :_total_
      row = self.col_order.inject({}) do |h,col|
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

  def build_cols_from_include(hash)
    return [] if hash.blank?
    hash.inject([]) do |a,(k,v)|
      v["columns"].each { |c| a << "#{k}.#{c}" }              if v.has_key?("columns")
      a += (self.build_cols_from_include(v["include"]) || []) if v.has_key?("include")
      a
    end
  end

  def build_includes(objs)
    results = []

    objs.each {|obj|
      entry = {:obj => obj}
      build_search_includes(obj, entry, self.include) if self.include
      results.push(entry)
    }

    results
  end

  def build_search_includes(obj, entry, includes)
    includes.each_key {|assoc|
      next unless obj.respond_to?(assoc)

      assoc_objects = [obj.send(assoc)].flatten.compact

      entry[assoc.to_sym] = assoc_objects.collect {|rec|
        new_entry = {:obj => rec}
        build_search_includes(rec, new_entry, includes[assoc]["include"]) if includes[assoc]["include"]
        new_entry
      }
    }
  end

  def build_reportable_data(entry, options = {})
    rec = entry[:obj]
    data_records = [build_get_attributes_with_options(rec, options)]
    rec.class.aar_columns |= data_records.first.keys

    data_records = build_add_includes(data_records, entry, options["include"]) if options["include"]
    data_records
  end

  def build_get_attributes_with_options(rec, options = {})
    only_or_except =
      if options[:only] || options[:except]
      { :only => options[:only], :except => options[:except] }
    end
    return {} unless only_or_except
    attrs = {}
    options[:only].each do |a|
      if self.class.is_trend_column?(a)
        attrs[a] = self.build_calculate_trend_point(rec, a)
      else
        attrs[a] = rec.send(a) if rec.respond_to?(a)
      end
    end
    attrs = attrs.inject({}) do |h,(k,v)|
      h["#{options[:qualify_attribute_names]}.#{k}"] = v; h
    end if options[:qualify_attribute_names]
    attrs
  end

  def build_add_includes(data_records, entry, includes)
    include_has_options = includes.is_a?(Hash)
    associations = include_has_options ? includes.keys : Array(includes)

    associations.each do |association|
      existing_records = data_records.dup
      data_records = []

      if include_has_options
        assoc_options = includes[association].merge({
            :qualify_attribute_names => association, :only =>  includes[association]["columns"]})
      else
        assoc_options = { :qualify_attribute_names => association, :only =>  includes[association]["columns"] }
      end

      if association == "categories" || association == "managed"
        association_objects = []
        assochash = {}
        @descriptions_by_tag_id ||= Classification.where("parent_id != 0").each_with_object({}) do |c, h|
          h[c.tag_id] = c.description
        end

        assoc_options[:only].each {|c|
          entarr = []
          entry[:obj].tags.each do |t|
            next unless t.name.starts_with?("/managed/#{c}/")
            next unless @descriptions_by_tag_id.has_key?(t.id)
            entarr << @descriptions_by_tag_id[t.id]
          end
          assochash[association + "." + c] = entarr unless entarr.empty?
        }
        # join the the category data together
        longest = 0
        idx = 0
        assochash.each_key {|k| longest = assochash[k].length if assochash[k].length > longest}
        longest.times {
          nh = {}
          assochash.each_key {|k| nh[k] = assochash[k][idx].nil? ? assochash[k].last : assochash[k][idx]}
          association_objects.push(nh)
          idx += 1
        }
      else
        association_objects = entry[association.to_sym]
      end

      existing_records.each do |existing_record|
        if association_objects.empty?
          data_records << existing_record
        else
          association_objects.each do |obj|
            unless association == "categories" || association == "managed"
              association_records = self.build_reportable_data(obj, assoc_options)
            else
              association_records = [obj]
            end
            association_records.each do |assoc_record|
              data_records << existing_record.merge(assoc_record)
            end
            entry[:obj].class.aar_columns |= data_records.last.keys
          end
        end
      end
    end
    data_records
  end

  def queue_report_result(options, res_opts)
    options[:userid] ||= "system"
    $log.info("MIQ(MiqReport-queue_report_result) Adding generate report task to the message queue...")
    task = MiqTask.create(:name => "Generate Report: '#{self.name}'", :userid => options[:userid])

    MiqQueue.put(
      :queue_name  => "reporting",
      :role        => "reporting",
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => "build_report_result",
      :msg_timeout => self.queue_timeout,
      :args        => [task.id, options, res_opts]
    )
    AuditEvent.success(:event => "generate_table", :target_class => self.class.base_class.name, :target_id => self.id, :userid => options[:userid], :message => "#{task.name}, successfully initiated")
    task.update_status("Queued", "Ok", "Task has been queued")

    $log.info("MIQ(MiqReport-queue_report_result) Finished adding generate report task with id [#{task.id}] to the message queue")
    return task.id
  end

  def build_report_result(taskid, options, res_opts = {})
    task = MiqTask.find(taskid)

    # Generate the table only if the task does not already contain a MiqReport object
    if task.task_results.blank?
      $log.info("MIQ(MiqReport-build_report_result) Generating report table with taskid [#{taskid}] and options [#{options.inspect}]")
      self._async_generate_table(taskid, options.merge(:mode => "schedule", :report_source => res_opts[:source]))

      # Reload the task after the _async_generate_table has updated it
      task.reload
      if task.status != "Ok"
        $log.warn("MIQ(MiqReport-build_report_result) Generating report table with taskid [#{taskid}]... Failed to complete, '#{task.message}'")
        return
      else
        $log.info("MIQ(MiqReport-build_report_result) Generating report table with taskid [#{taskid}]... Complete")
      end
    end

    res_last_run_on  = Time.now.utc

    # If a scheduler :at time was provided, convert that to a Time object, otherwise use the current time
    if res_opts[:at]
      raise "Expected scheduled time 'at' to be 'numeric', received '#{res_opts[:at].class}'" unless res_opts[:at].is_a?(Numeric)
      at = Time.at(res_opts[:at]).utc
    else
      at = res_last_run_on
    end

    res = task.miq_report_result
    nh = {:miq_task_id => taskid, :scheduled_on => at}
    $log.info("MIQ(MiqReport-build_report_result) Updating report results with hash: [#{nh.inspect}]")
    res.update_attributes(nh)
    $log.info("MIQ(MiqReport-build_report_result) Finished creating report result with id [#{res.id}] for report id: [#{self.id}], name: [#{self.name}]")

    notify_user_of_report(res_last_run_on, res, options) if options[:send_email]

    # Remove the table in the task_results since we now have it in the report_results
    task.task_results = nil
    task.save
    res
  end

  def table_has_records?
    self.table.length > 0
  end

  def queue_timeout
    ((self.rpt_options || {})[:queue_timeout] || self.class.default_queue_timeout).to_i_with_method
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
    return self.time_profile ? self.time_profile.tz || self.tz || default_tz : self.tz || default_tz
  end

end
