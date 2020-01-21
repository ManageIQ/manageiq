class VimPerformanceTagValue
  attr_accessor :tag_name, :association_type, :category, :column_name, :value, :assoc_ids

  TAG_SEP = "|"
  TAG_COLS = {
    :Storage => [
      "derived_storage_vm_count_managed",
      "derived_storage_used_managed",
      "derived_storage_disk_managed",
      "derived_storage_snapshot_managed",
      "derived_storage_mem_managed",
      "assoc_ids"
    ],
    :default => [
      "cpu_usagemhz_rate_average",
      "cpu_usage_rate_average",
      "v_pct_cpu_ready_delta_summation",
      "derived_memory_used",
      "disk_usage_rate_average",
      "net_usage_rate_average",
      "assoc_ids"
    ]
  }

  RESOURCE_TYPE_TO_ASSOCIATIONS = {
    "MiqEnterprise"       => [:miq_regions],
    "MiqRegion"           => [:ext_management_systems],
    "ExtManagementSystem" => [:vms, :hosts, :ems_clusters],
    "Storage"             => [:vms, :hosts],
    "EmsCluster"          => [:vms, :hosts],
    "Host"                => [:vms],
    "AvailabilityZone"    => [:vms],
    "VmOrTemplate"        => [],
    "ContainerNode"       => [],
    "Container"           => [],
    "ContainerGroup"      => [],
    "ContainerProject"    => [],
    "ContainerService"    => [],
    "ContainerReplicator" => [],
    "Service"             => [:vms]
  }

  def initialize(options = {})
    options.each { |k, v| public_send("#{k}=", v) }
  end

  def self.build_from_performance_record(parent_perf, options = {})
    RESOURCE_TYPE_TO_ASSOCIATIONS[parent_perf.resource_type].collect { |assoc| build_for_association(parent_perf, assoc, options) }.flatten
  end

  cache_with_timeout(:eligible_categories, 5.minutes) { Classification.category_names_for_perf_by_tag }

  def self.build_for_association(parent_perf, assoc, options = {})
    eligible_cats = eligible_categories
    return [] if eligible_cats.empty?

    ts = parent_perf.timestamp
    children = parent_perf.resource.send("#{assoc}_from_vim_performance_state_for_ts", ts)
    return [] if children.empty?
    vim_performance_daily = parent_perf.kind_of?(VimPerformanceDaily)
    recs = get_metrics(children, ts, parent_perf.capture_interval_name, vim_performance_daily, options[:category])

    result = {}
    counts = {}
    association_type = nil
    tag_cols = TAG_COLS.key?(parent_perf.resource_type.to_sym) ? TAG_COLS[parent_perf.resource_type.to_sym] : TAG_COLS[:default]

    perf_data = {}
    perf_data[:perf_recs] = recs
    perf_data[:categories] = perf_data[:perf_recs].collect do |perf|
      perf.tag_names.split(TAG_SEP).collect { |t| t.split("/").first } unless perf.tag_names.nil?
    end.flatten.compact.uniq

    cats_to_process = (eligible_cats & perf_data[:categories]) # Process subset of perf_data[:categories] that are eligible for tag grouping
    return [] if cats_to_process.empty?

    perf_data[:perf_recs].each do |perf|
      association_type = perf.resource_type

      cats_to_process.each do |category|
        if !perf.tag_names.nil? && perf.tag_names.include?(category)
          tag_names = perf.tag_names.split(TAG_SEP).select { |t| t.starts_with?(category) }
        else
          tag_names = ["#{category}/_none_"]
        end
        tag_names.each do |tag|
          next if tag.starts_with?("power_state")
          next if tag.starts_with?("folder_path")
          tag_cols.each do |c|
            value = perf.send(c)
            c = [c.to_s, tag].join(TAG_SEP).to_sym

            if c.to_s.starts_with?("assoc_ids")
              assoc = perf.resource.class.table_name.to_sym
              result[c] ||= {assoc => {:on => []}}
              result[c][assoc][:on].push(perf.resource_id)
            else
              result[c] ||= 0
              counts[c] ||= 0
              value *= 1.0 unless value.nil?
              Metric::Aggregation::Aggregate.average(c, nil, result, counts, value)
            end
          end
        end
      end
    end

    result.keys.inject([]) do |a, key|
      col, tag = key.to_s.split(TAG_SEP)
      category = tag.split("/").first
      tag_name = tag.split("/").last
      Metric::Aggregation::Process.average(key, nil, result, counts) unless col.to_s.starts_with?("assoc_ids", "derived_storage_vm_count")
      new_rec = {
        :association_type => association_type,
        :category         => category,
        :tag_name         => tag_name,
        :column_name      => col
      }
      attr = col == 'assoc_ids' ? :assoc_ids : :value
      new_rec[attr] = result[key]

      a << new(new_rec)
    end
  end

  def self.get_metrics(resources, timestamp, capture_interval_name, vim_performance_daily, category)
    if vim_performance_daily
      MetricRollup.with_interval_and_time_range("hourly", (timestamp)..(timestamp+1.day)).where(:resource => resources)
          .for_tag_names(category, "") # append trailing slash
    else
      Metric::Helper.class_for_interval_name(capture_interval_name).where(:resource => resources)
          .with_interval_and_time_range(capture_interval_name, timestamp)
    end
  end

  private_class_method :get_metrics

  def self.tag_cols(name)
    return TAG_COLS[name.to_sym] if TAG_COLS.key?(name.to_sym)
    TAG_COLS[:default]
  end
end # class VimPerformanceTagValue
