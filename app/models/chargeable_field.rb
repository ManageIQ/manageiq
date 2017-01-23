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

  def measure(consumption)
    return 1.0 if fixed?
    return 0 if consumption.none?(metric)
    return consumption.max(metric) if allocated?
    return consumption.avg(metric) if used?
  end

  def fixed?
    group == 'fixed'
  end

  def adjustment_to(target_unit)
    # return multiplicator, that would bring UNITS[metric] to target_unit
    UNITS[metric] ? detail_measure.adjust(target_unit, UNITS[metric]) : 1
  end

  private

  def used?
    source == 'used'
  end

  def allocated?
    source == 'allocated'
  end

  def self.seed
    seed_data.each do |f|
      rec = ChargeableField.find_by(:metric => f[:metric])
      measure = f.delete(:measure)
      if measure
        f[:chargeback_rate_detail_measure_id] = ChargebackRateDetailMeasure.find_by!(:name => measure).id
      end
      if rec.nil?
        create(f)
      else
        rec.update_attributes!(f)
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
