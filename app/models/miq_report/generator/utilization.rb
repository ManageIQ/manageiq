module MiqReport::Generator::Utilization
  def build_results_for_report_utilization(_options)
    # self.db_options = {
    #   :rpt_type       => "utilization",
    #   :interval       => "daily",
    #   :start_date     =>
    #   :end_date       =>
    #   :resource_type  => "ExtManagementSystem"
    #   :resource_id    => 5
    #   :tag            => "Host/environment/prod"

    resource = Object.const_get(db_options[:resource_type]).find_by_id(db_options[:resource_id])
    raise "unable to find #{db_options[:resource_type]} with id #{db_options[:resource_id]}" if resource.nil?

    if db_options[:tag]
      tag_klass, cat, tag = db_options[:tag].split("/")
      cond = ["resource_type = ? and tag_names like ?", tag_klass, "%#{cat}/#{tag}%"]
      results = VimPerformanceAnalysis.find_child_perf_for_time_period(resource, db_options[:interval], db_options.merge(:conditions => cond, :ext_options => {:only_cols => cols, :tz => tz, :time_profile => time_profile}))

      # Roll up results by timestamp
      results = VimPerformanceAnalysis.group_perf_by_timestamp(resource, results, cols)
    else
      results = VimPerformanceAnalysis.find_perf_for_time_period(resource, db_options[:interval], db_options.merge(:ext_options => {:only_cols => cols, :tz => tz, :time_profile => time_profile}))
    end

    # Return rpt object:
    #   One line per day
    # => Add child prefs by day
    [results]
  end
end
