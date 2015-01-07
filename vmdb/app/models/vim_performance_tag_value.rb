class VimPerformanceTagValue < ActiveRecord::Base
  belongs_to :metric, :polymorphic => true

  serialize :assoc_ids

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
    "VmOrTemplate"        => []
  }

  def self.build_from_performance_record(parent_perf, options={:save => true})
    RESOURCE_TYPE_TO_ASSOCIATIONS[parent_perf.resource_type].collect {|assoc| self.build_for_association(parent_perf, assoc, options)}.flatten
  end

  cache_with_timeout(:eligible_categories, 5.minutes) { Classification.category_names_for_perf_by_tag }

  def self.build_for_association(parent_perf, assoc, options={:save => true})
    eligible_cats = self.eligible_categories
    return [] if eligible_cats.empty?

    ts = parent_perf.timestamp
    children = parent_perf.resource.send("#{assoc}_from_vim_performance_state_for_ts", ts)
    return [] if children.empty?

    result = {}
    counts = {}
    assoc = nil
    association_type = nil
    tag_cols = TAG_COLS.has_key?(parent_perf.resource_type.to_sym) ? TAG_COLS[parent_perf.resource_type.to_sym] : TAG_COLS[:default]

    if parent_perf.kind_of?(VimPerformanceDaily)
      klass = MetricRollup
      conditions = [
        "resource_type = ? AND resource_id IN (?) AND (timestamp >= ? AND timestamp < ?) AND tag_names LIKE ? AND capture_interval_name = 'hourly'",
        children.first.class.base_class.name,
        children.collect {|c| c.id},
        ts, ts + 1.day, "%#{options[:category]}/%"
      ]
    else
      klass, meth = Metric::Helper.class_and_association_for_interval_name(parent_perf.capture_interval_name)
      conditions = {
        :resource_type         => children.first.class.base_class.name,
        :resource_id           => children.collect {|c| c.id},
        :timestamp             => parent_perf.timestamp,
        :capture_interval_name => parent_perf.capture_interval_name
      }
    end
    perf_data = {}
    perf_data[:perf_recs] = klass.where(conditions)
    perf_data[:categories] = perf_data[:perf_recs].collect do |perf|
      perf.tag_names.split(TAG_SEP).collect {|t| t.split("/").first} unless perf.tag_names.nil?
    end.flatten.compact.uniq

    cats_to_process = (eligible_cats & perf_data[:categories]) # Process subset of perf_data[:categories] that are eligible for tag grouping
    return [] if cats_to_process.empty?

    perf_data[:perf_recs].each do |perf|
      association_type = perf.resource_type

      cats_to_process.each do |category|
        if !perf.tag_names.nil? && perf.tag_names.include?(category)
          tag_names = perf.tag_names.split(TAG_SEP).select {|t| t.starts_with?(category)}
        else
          tag_names = ["#{category}/_none_"]
        end
        tag_names.each do |tag|
          next if tag.starts_with?("power_state")
          next if tag.starts_with?("folder_path")
          tag_cols.each do |c|
            value = perf.send(c)
            c = [c.to_s, tag].join(TAG_SEP).to_sym

            unless c.to_s.starts_with?("assoc_ids")
              result[c] ||= 0
              counts[c] ||= 0
              value = value * 1.0 unless value.nil?
              Metric::Aggregation::Aggregate.average(c, nil, result, counts, value)
            else
              assoc = perf.resource.class.table_name.to_sym
              result[c] ||= {assoc => {:on => []}}
              result[c][assoc][:on].push(perf.resource_id)
            end
          end
        end
      end
    end

    parent_perf_tag_value_recs = parent_perf.vim_performance_tag_values.inject({}) do |h, tv|
      h.store_path(tv.association_type, tv.category, tv.tag_name, tv.column_name, tv)
      h
    end

    result.keys.inject([]) do |a,key|
      col, tag = key.to_s.split(TAG_SEP)
      category = tag.split("/").first
      tag_name = tag.split("/").last
      Metric::Aggregation::Process.average(key, nil, result, counts) unless col.to_s.starts_with?("assoc_ids") || col.to_s.starts_with?("derived_storage_vm_count")
      new_rec = {
        :association_type => association_type,
        :category         => category,
        :tag_name         => tag_name,
        :column_name      => col
      }
      attr = col == 'assoc_ids' ? :assoc_ids : :value
      new_rec[attr] = result[key]
      if options[:save]
        tag_value_rec   = parent_perf_tag_value_recs.fetch_path(association_type, category, tag_name, col)
        tag_value_rec ||= parent_perf_tag_value_recs.store_path(association_type, category, tag_name, col, parent_perf.vim_performance_tag_values.build)
        tag_value_rec.update_attributes(new_rec)
      else
        tag_value_rec = self.new(new_rec)
      end
      a << tag_value_rec
    end
  end

  def self.tag_cols(name)
    return TAG_COLS[name.to_sym] if TAG_COLS.has_key?(name.to_sym)
    return TAG_COLS[:default]
  end
end #class VimPerformanceTagValue
