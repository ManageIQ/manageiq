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

  validates :metric, :uniqueness => true, :presence => true
  validates :group, :source, :presence => true

  # returns category(Vm, Container), measure (CPU, MEM, .. ), dimension(max_number, max_mem)
  def showback_measure
    group
  end

  def showback_dimension
    {'cpu_usagemhz_rate_average'         => ['cpu_usagemhz_rate_average', 'Mhz', 'duration'],
     "v_derived_cpu_total_cores_used"    => ['v_derived_cpu_total_cores_used', '', 'duration'],
     "derived_vm_numvcpus"               => ['derived_vm_numvcpus', '', 'duration'],
     "derived_memory_used"               => ['derived_memory_used', 'B', 'duration'],
     "derived_memory_available"          => ['derived_memory_available', 'B', 'duration'],
     "net_usage_rate_average"            => ['net_usage_rate_average', '',''],
     "disk_usage_rate_average"           => ['disk_usage_rate_average', '',''],
     "fixed_compute_1"                   => ['fixed_compute_1','', 'occurrence'],
     "fixed_compute_2"                   => ['fixed_compute_2','', 'occurrence'],
     "derived_vm_allocated_disk_storage" => ['derived_vm_allocated_disk_storage', '',''],
     "derived_vm_used_disk_storage"      => ['derived_vm_used_disk_storage', '',''],
     "fixed_storage_1"                   => ['fixed_storage_1', '',''],
     "fixed_storage_2"                   => ['fixed_storage_2', '','']}[metric]
  end

  def measure(consumption, options)
    return consumption.consumed_hours_in_interval if metering?
    return 1.0 if fixed?
    return 0 if consumption.none?(metric)
    return consumption.send(options.method_for_allocated_metrics, metric) if allocated?
    return consumption.avg(metric) if used?
  end

  def fixed?
    group == 'fixed'
  end

  def adjustment_to(target_unit)
    # return multiplicator, that would bring UNITS[metric] to target_unit
    UNITS[metric] ? detail_measure.adjust(target_unit, UNITS[metric]) : 1
  end

  def metric_key
    "#{rate_name}_metric" # metric value (e.g. Storage [Used|Allocated|Fixed])
  end

  def cost_keys
    ["#{rate_name}_cost",   # cost associated with metric (e.g. Storage [Used|Allocated|Fixed] Cost)
     "#{group}_cost",       # cost associated with metric's group (e.g. Storage Total Cost)
     'total_cost']
  end

  def metering?
    group == 'metering' && source == 'used'
  end

  private

  def rate_name
    "#{group}_#{source}"
  end

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

  def self.chargeable_cols_on_metric_rollup
    existing_cols = MetricRollup.attribute_names
    chargeable_cols = pluck(:metric) & existing_cols
    chargeable_cols.map! { |x| VIRTUAL_COL_USES[x] || x }
  end
end
