class ManageIQ::Providers::Google::CloudManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  # List of counters we expose to the caller
  VIM_STYLE_COUNTERS = {
    "cpu_usage_rate_average"  => {
      :counter_key           => "cpu_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "percent",
      :capture_interval_name => "realtime"
    },
    "disk_usage_rate_average" => {
      :counter_key           => "disk_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    },
    "net_usage_rate_average"  => {
      :counter_key           => "net_usage_rate_average",
      :instance              => "",
      :capture_interval      => "20",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    }
  }.freeze

  # Mapping from VIM counter name to our local descriptor. This describes how
  # to translate a google metric into the corresponding ManageIQ metric.
  #
  # See the first schema for a description of each field.
  VIM_COUNTER_SCHEMAS = [
    {
      # Name of the VIM_STYLE_COUNTER this schema describes
      :vim_counter_name        => "cpu_usage_rate_average",

      # List of metric names in GCP that should be retrieved to calculate the
      # vim-style metric
      :google_metric_names     => ["compute.googleapis.com/instance/cpu/utilization"],

      # A function that maps a target to a list of google labels to be applied
      # to the request. Only results matching the label are returned.
      :target_to_google_labels => ->(target) { ["compute.googleapis.com/resource_id==#{target.ems_ref}"] },

      # Function that maps a point returned by Google's monitoring api (which
      # is a hash data structure; see
      # https://cloud.google.com/monitoring/v2beta2/timeseries) to our counter
      # value. Any unit transformations are applied as well.
      :point_to_val            => ->(point) { point["doubleValue"].to_f * 100 },

      # Function that takes two points and reduces them to one. This is used
      # when multiple points are found for the same data point in the same
      # query (e.g. if we are querying disk usage and the host has multiple
      # disks, this method is used to combine the points into a single metric)
      :reducer                 => lambda do |x, _|
        _log.warn("Received multiple values for cpu_usage; ignoring duplicates")
        x
      end
    },
    {
      :vim_counter_name        => "disk_usage_rate_average",
      :google_metric_names     => ["compute.googleapis.com/instance/disk/read_bytes_count",
                                   "compute.googleapis.com/instance/disk/write_bytes_count"],
      :target_to_google_labels => ->(target) { ["compute.googleapis.com/resource_id==#{target.ems_ref}"] },
      :point_to_val            => ->(point) { point["int64Value"].to_i / (60.0 * 1024.0) }, # convert from b/m to Kb/s
      :reducer                 => ->(x, y) { x + y },
    },
    {
      :vim_counter_name        => "net_usage_rate_average",
      :google_metric_names     => ["compute.googleapis.com/instance/network/received_bytes_count",
                                   "compute.googleapis.com/instance/network/sent_bytes_count"],
      :target_to_google_labels => ->(target) { ["compute.googleapis.com/resource_id==#{target.ems_ref}"] },
      :point_to_val            => ->(point) { point["int64Value"].to_i / (60.0 * 1024.0) }, # convert from b/m to Kb/s
      :reducer                 => ->(x, y) { x + y },
    }
  ].freeze

  def perf_collect_metrics(_interval_name, start_time = nil, end_time = nil)
    raise "No EMS defined" if target.ext_management_system.nil?

    # Currently we only know how to capture VMs
    return [{}, {}] unless target.type == ManageIQ::Providers::Google::CloudManager::Vm.name

    end_time   ||= Time.now.utc
    end_time     = end_time.utc
    start_time ||= end_time - 4.hours # 4 hours for symmetry with VIM (still needed?)
    start_time   = start_time.utc

    counter_values_by_ts = {}
    target.ext_management_system.with_provider_connection(:service => 'monitoring') do |google|
      VIM_COUNTER_SCHEMAS.each do |schema|
        collect_metrics(google, start_time, end_time, schema, counter_values_by_ts)
      end
    end

    # Now that we've collected the data, transform it into 20-second metrics
    # by interpolation. For now we just set the interpolated value to the
    # value at the closest minute rounded-down.
    #
    # Note that we can do this because all three VM metrics are "gauge" style
    # metrics - a delta metric would require further transformation.
    add_20_second_interpolated_points(counter_values_by_ts, end_time)

    counters_by_id              = {target.ems_ref => VIM_STYLE_COUNTERS}
    counter_values_by_id_and_ts = {target.ems_ref => counter_values_by_ts}

    return counters_by_id, counter_values_by_id_and_ts
  end

  # Lookup and retrieve a metric from Google Cloud, storing it in the
  # 'counter_values_by_ts' hash. Note that this method retrieves, transforms
  # and collects a metric according to a metric schema (see
  # VIM_COUNTER_SCHEMAS for examples).
  #
  # @param google [Fog::Google::Monitoring] monitoring client instance to use
  #   for retrieving metrics
  # @param start_time [Time] the earliest point to query
  # @param end_time [Time] the latest point to query
  # @param schema [Hash] schema describing metric to query (see
  #   VIM_STYLE_COUNTERS definition for a description)
  # @param counter_values_by_ts [Hash{Time => Hash{String => Number}}] hash to
  #   aggregate metrics onto (will be modified by method)
  # @return nil
  def collect_metrics(google, start_time, end_time, schema, counter_values_by_ts)
    schema[:google_metric_names].each do |google_metric_name|
      options = {
        :labels => schema[:target_to_google_labels].call(target),
        :oldest => start_time.to_datetime.rfc3339,
      }
      # Make our service call for metrics; Note that we might get multiple
      # time series back (for example, if the host has multiple disks/network
      # cards)
      tss = google.timeseries_collection.all(google_metric_name, end_time.to_datetime.rfc3339, options)

      tss.each do |ts|
        collect_time_series_metrics(ts, schema, counter_values_by_ts)
      end
    end
  end

  # Collect the metrics from a time series returned by Google cloud into the
  # provided 'counter_values_by_ts' hash, using the provided schema.
  #
  # @param time_series [Hash] resource returned by GCP describing a metric
  #   lookup result (see https://cloud.google.com/monitoring/v2beta2/timeseries)
  # @param schema [Hash] schema describing the metric to query (see
  #   VIM_STYLE_COUNTERS definition for a description)
  # @param counter_values_by_ts [Hash{Time => Hash{String => Number}}] hash to
  #   aggregate metrics onto (will be modified by method)
  # @return nil
  def collect_time_series_metrics(time_series, schema, counter_values_by_ts)
    time_series.points.each do |point|
      # Parse out the time object and set it to the beginning of the
      # minute; this allows us to sum up points across time series that may
      # have landed on different seconds. Note this only holds true for
      # 1-minute metrics.
      timestamp = Time.zone.parse(point["start"]).beginning_of_minute
      val = schema[:point_to_val].call(point)

      # If we already have a value, reduce using our reduction function
      prev_val = counter_values_by_ts.fetch_path(timestamp, schema[:vim_counter_name])
      unless prev_val.nil?
        val = schema[:reducer].call(prev_val, val)
      end

      counter_values_by_ts.store_path(timestamp, schema[:vim_counter_name], val)
    end
  end

  # Transform a provided counter_values_by_ts struct by interpolating values
  # for the :20 and :40 suffixes. Note that this method assumes the value for
  # interpolation lies on the :00 suffix. Also note this is only correct for a
  # gauge-style metric.
  #
  # @param counter_values_by_ts [Hash{Time => Hash{String => Number}}] hash to
  #   interpolate metrics onto (will be modified by method)
  # @param end_time [Time] time that points will not be interpolated beyond
  # @return nil
  def add_20_second_interpolated_points(counter_values_by_ts, end_time)
    counter_values_by_ts.keys.each do |ts|
      # Skip any already interpolated values
      next if ts.sec != 0

      # Create a :20 and a :40 entry for every counter name
      counter_values_by_ts[ts].each do |counter_name, counter_val|
        [ts + 20.seconds, ts + 40.seconds].each do |interpolated_ts|
          # Make sure we don't interpolate past our requested range
          next if interpolated_ts > end_time

          counter_values_by_ts.store_path(interpolated_ts, counter_name, counter_val)
        end
      end
    end
  end
end
