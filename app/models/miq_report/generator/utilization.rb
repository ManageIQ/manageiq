module MiqReport::Generator::Utilization
  def build_results_for_report_utilization(options)
    # self.db_options = {
    #   :rpt_type       => "utilization",
    #   :interval       => "daily",
    #   :start_date     =>
    #   :end_date       =>
    #   :resource_type  => "ExtManagementSystem"
    #   :resource_id    => 5
    #   :tag            => "Host/environment/prod"

    resource = Object::const_get(self.db_options[:resource_type]).find_by_id(self.db_options[:resource_id])
    raise "unable to find #{self.db_options[:resource_type]} with id #{self.db_options[:resource_id]}" if resource.nil?

    if self.db_options[:tag]
      tag_klass, cat, tag = self.db_options[:tag].split("/")
      cond = ["resource_type = ? and tag_names like ?", tag_klass, "%#{cat}/#{tag}%"]
      results = VimPerformanceAnalysis.find_child_perf_for_time_period(resource, self.db_options[:interval], self.db_options.merge(:conditions => cond, :ext_options => {:only_cols => self.cols, :tz => self.tz, :time_profile => self.time_profile}))

      # Roll up results by timestamp
      results = VimPerformanceAnalysis.group_perf_by_timestamp(resource, results, self.cols)
    else
      results = VimPerformanceAnalysis.find_perf_for_time_period(resource, self.db_options[:interval], self.db_options.merge(:ext_options => {:only_cols => self.cols, :tz => self.tz, :time_profile => self.time_profile}))
    end

    # Return rpt object:
    #   One line per day
    # => Add child prefs by day
    return [results]
  end
end
