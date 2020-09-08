class ChargeableField < ApplicationRecord
  VIRTUAL_COL_USES = {
    'v_derived_cpu_total_cores_used' => 'cpu_usage_rate_average'
  }.freeze

  # The following chargeable fields are stored in following units
  UNITS = {
    'cpu_usagemhz_rate_average'         => 'megahertz',
    'derived_memory_used'               => 'megabytes',
    'derived_memory_available'          => 'megabytes',
    'net_usage_rate_average'            => 'kbps',
    'disk_usage_rate_average'           => 'kbps',
    'derived_vm_allocated_disk_storage' => 'bytes',
    'derived_vm_used_disk_storage'      => 'bytes'
  }.freeze

  belongs_to :detail_measure, :class_name => 'ChargebackRateDetailMeasure', :foreign_key => :chargeback_rate_detail_measure_id

  validates :metric, :uniqueness_when_changed => true, :presence => true
  validates :group, :source, :presence => true

  def showback_measure
    group
  end

  def showback_dimension
    metric_index = VIRTUAL_COL_USES.invert[metric] || metric
    {'cpu_usagemhz_rate_average'         => ['cpu_usagemhz_rate_average', '', 'duration'],
     "v_derived_cpu_total_cores_used"    => ['v_derived_cpu_total_cores_used', 'THz', 'duration'],
     "derived_vm_numvcpus"               => ['derived_vm_numvcpus', '', 'duration'],
     "derived_memory_used"               => ['derived_memory_used', 'Gi', 'duration'],
     "derived_memory_available"          => ['derived_memory_available', 'B', 'duration'],
     "metering_used_hours"               => ['metering_used_hours', '', 'quantity'],
     "net_usage_rate_average"            => ['net_usage_rate_average', '', 'duration'],
     "disk_usage_rate_average"           => ['disk_usage_rate_average', '', 'duration'],
     "fixed_compute_1"                   => ['fixed_compute_1', '', 'occurrence'],
     "fixed_compute_2"                   => ['fixed_compute_2', '', 'occurrence'],
     "derived_vm_allocated_disk_storage" => ['derived_vm_allocated_disk_storage', 'Gi', 'duration'],
     "derived_vm_used_disk_storage"      => ['derived_vm_used_disk_storage', 'Gi', 'duration'],
     "fixed_storage_1"                   => ['fixed_storage_1', '', 'occurrence'],
     "fixed_storage_2"                   => ['fixed_storage_2', '', 'occurrence']}[metric_index]
  end

  def measure_metering(consumption, options, sub_metric = nil)
    used? ? consumption.sum(metric) : measure(consumption, options, sub_metric)
  end

  def measure(consumption, options, sub_metric = nil)
    return consumption.consumed_hours_in_interval if metering?
    return 1.0 if fixed?
    return 0 if options.method_for_allocated_metrics != :current_value && consumption.none?(metric, sub_metric)
    return consumption.send(options.method_for_allocated_metrics, metric, sub_metric) if allocated?
    return consumption.avg(metric) if used?
  end

  def fixed?
    group == 'fixed'
  end

  def adjustment_to(target_unit)
    # return multiplicator, that would bring UNITS[metric] to target_unit
    UNITS[metric] ? detail_measure.adjust(target_unit, UNITS[metric]) : 1
  end

  def rate_key(sub_metric = nil)
    "#{rate_name}_#{sub_metric ? sub_metric + '_' : ''}rate" # rate value (e.g. Storage [Used|Allocated|Fixed] Rate)
  end

  def metric_key(sub_metric = nil)
    "#{rate_name}_#{sub_metric ? sub_metric + '_' : ''}metric" # metric value (e.g. Storage [Used|Allocated|Fixed])
  end

  # Fixed metric has _1 or _2 in name but column
  # fixed_compute_metric is used in report and calculations
  # TODO: remove and unify with metric_key
  def metric_column_key
    fixed? ? metric_key.gsub(/\_1|\_2/, '') : metric_key
  end

  def cost_keys(sub_metric = nil)
    keys = ["#{rate_name}_#{sub_metric ? sub_metric + '_' : ''}cost", # cost associated with metric (e.g. Storage [Used|Allocated|Fixed] Cost)
            'total_cost']

    sub_metric ? keys : keys + ["#{group}_cost"] # cost associated with metric's group (e.g. Storage Total Cost)
  end

  def metering?
    group == 'metering' && source == 'used'
  end

  def rate_name
    "#{group}_#{source}"
  end

  def self.cols_on_metric_rollup
    (%w(id tag_names resource_id) + chargeable_cols_on_metric_rollup).uniq
  end

  def self.col_index(column)
    @rate_cols ||= {}
    column = VIRTUAL_COL_USES[column] || column
    @rate_cols[column] ||= cols_on_metric_rollup.index(column.to_s)
  end

  private

  def used?
    source == 'used'
  end

  def allocated?
    source == 'allocated'
  end

  def self.seed
    measures = ChargebackRateDetailMeasure.all.index_by(&:name)
    existing = ChargeableField.all.index_by(&:metric)
    seed_data.each do |f|
      measure = f.delete(:measure)
      if measure
        f[:chargeback_rate_detail_measure_id] = measures[measure].id
      end
      rec = existing[f[:metric]]
      if rec.nil?
        create(f)
      else
        rec.attributes = f
        rec.save! if rec.changed?
      end
    end
  end

  def self.seed_data
    fixture_file = File.join(FIXTURE_DIR, 'chargeable_fields.yml')
    File.exist?(fixture_file) ? YAML.load_file(fixture_file) : []
  end

  private_class_method :seed_data

  def self.chargeable_cols_on_metric_rollup
    existing_cols = MetricRollup.attribute_names
    chargeable_cols = pluck(:metric) & existing_cols
    chargeable_cols.map! { |x| VIRTUAL_COL_USES[x] || x }.sort
  end

  private_class_method :chargeable_cols_on_metric_rollup
end
