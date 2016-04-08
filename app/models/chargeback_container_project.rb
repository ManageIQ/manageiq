class ChargebackContainerProject < Chargeback
  set_columns_hash(
    :start_date           => :datetime,
    :end_date             => :datetime,
    :interval_name        => :string,
    :display_range        => :string,
    :project_name         => :string,
    :cpu_used_cost        => :float,
    :cpu_used_metric      => :float,
    :cpu_cost             => :float,
    :cpu_metric           => :float,
    :fixed_compute_1_cost => :float,
    :fixed_compute_2_cost => :float,
    :fixed_2_cost         => :float,
    :fixed_cost           => :float,
    :memory_used_cost     => :float,
    :memory_used_metric   => :float,
    :memory_cost          => :float,
    :memory_metric        => :float,
    :net_io_used_cost     => :float,
    :net_io_used_metric   => :float,
    :net_io_cost          => :float,
    :net_io_metric        => :float,
    :total_cost           => :float
  )

  def self.build_results_for_report_ChargebackContainerProject(options)
    # Options:
    #   :rpt_type => chargeback
    #   :interval => daily | weekly | monthly
    #   :start_time
    #   :end_time
    #   :end_interval_offset
    #   :interval_size
    #   :owner => <userid>
    #   :tag => /managed/environment/prod (Mutually exclusive with :user)
    #   :chargeback_type => detail | summary
    #   :entity_id => 1/2/3.../all rails id of entity
    _log.info("Calculating chargeback costs...")

    tz = Metric::Helper.get_time_zone(options[:ext_options])
    # TODO: Support time profiles via options[:ext_options][:time_profile]

    interval = options[:interval] || "daily"
    cb = new

    # Find Project by id or get all projects
    id = options[:entity_id]
    raise "must provide option :entity_id" if id.nil?

    groups = if id == "all"
               ContainerGroup.all
             else
               ContainerGroup.where('container_project_id = ? or old_container_project_id = ?', id, id)
             end

    groups = groups.includes(:container_project, :old_container_project)
    return [[]] if groups.empty?

    data_index = {}
    groups.each do |g|
      data_index.store_path(:container_project, :by_group_id, g.id, g.container_project || g.old_container_project)
    end

    options[:ext_options] ||= {}

    base_rollup = MetricRollup.includes(
      :resource           => :hardware,
      :parent_host        => :tags,
      :parent_ems_cluster => :tags,
      :parent_storage     => :tags,
      :parent_ems         => :tags)
                              .select(*Metric::BASE_COLS).order("resource_id, timestamp")
    perf_cols = MetricRollup.attribute_names
    rate_cols = ChargebackRate.where(:default => true).flat_map do |rate|
      rate.chargeback_rate_details.map(&:metric).select { |metric| perf_cols.include?(metric.to_s) }
    end
    base_rollup = base_rollup.select(*rate_cols)

    timerange = get_report_time_range(options, interval, tz)
    data = {}

    timerange.step_value(1.day).each_cons(2) do |query_start_time, query_end_time|
      recs = base_rollup.where(:timestamp => query_start_time...query_end_time, :capture_interval_name => "hourly")
      recs = recs.where(:resource_type => ContainerGroup.name, :resource_id => groups.pluck(:id))
      recs = Metric::Helper.remove_duplicate_timestamps(recs)

      _log.info("Found #{recs.length} records for time range #{[query_start_time, query_end_time].inspect}")

      unless recs.empty?
        ts_key = get_group_key_ts(recs.first, interval, tz)

        recs.each do |perf|
          next if perf.resource.nil?
          project = data_index.fetch_path(:container_project, :by_group_id, perf.resource_id)
          key = "#{project.id}_#{ts_key}"

          if data[key].nil?
            start_ts, end_ts, display_range = get_time_range(perf, interval, tz)
            data[key] = {
              "start_date"    => start_ts,
              "end_date"      => end_ts,
              "display_range" => display_range,
              "interval_name" => interval,
              "project_name"  => project.name
            }
          end

          rates_to_apply = cb.get_rates(perf)
          calculate_costs(perf, data[key], rates_to_apply)
        end
      end
    end
    _log.info("Calculating chargeback costs...Complete")

    [data.map { |r| new(r.last) }]
  end

  def self.report_col_options
    {
      "cpu_cost"             => {:grouping => [:total]},
      "cpu_metric"           => {:grouping => [:total]},
      "cpu_used_cost"        => {:grouping => [:total]},
      "cpu_used_metric"      => {:grouping => [:total]},
      "fixed_compute_1_cost" => {:grouping => [:total]},
      "fixed_compute_2_cost" => {:grouping => [:total]},
      "fixed_cost"           => {:grouping => [:total]},
      "fixed_storage_1_cost" => {:grouping => [:total]},
      "fixed_storage_2_cost" => {:grouping => [:total]},
      "memory_cost"          => {:grouping => [:total]},
      "memory_metric"        => {:grouping => [:total]},
      "memory_used_cost"     => {:grouping => [:total]},
      "memory_used_metric"   => {:grouping => [:total]},
      "net_io_cost"          => {:grouping => [:total]},
      "net_io_metric"        => {:grouping => [:total]},
      "net_io_used_cost"     => {:grouping => [:total]},
      "net_io_used_metric"   => {:grouping => [:total]},
      "total_cost"           => {:grouping => [:total]}
    }
  end
end # class Chargeback
