# @see Metric
class MetricRollup < ApplicationRecord
  # Specify the primary key for a model backed by a view
  self.primary_key = "id"

  include Metric::Common
  include_concern 'Metric::ChargebackHelper'

  CHARGEBACK_METRIC_FIELDS = %w(derived_vm_numvcpus cpu_usagemhz_rate_average
                                cpu_usage_rate_average disk_usage_rate_average
                                derived_memory_available derived_memory_used
                                net_usage_rate_average derived_vm_used_disk_storage
                                derived_vm_allocated_disk_storage).freeze

  METERING_USED_METRIC_FIELDS = %w(cpu_usagemhz_rate_average derived_memory_used net_usage_rate_average).freeze

  CAPTURE_INTERVAL_NAMES = %w(hourly daily).freeze

  #
  # min_max column getters
  #

  Metric::Rollup::ROLLUP_COLS.product([:min, :max]).each do |c, mode|
    col = "#{mode}_#{c}".to_sym
    define_method(col) { extract_from_min_max(col) }
    virtual_column col, :type => :float
  end

  Metric::Rollup::BURST_COLS.product([:min, :max]).each do |c, mode|
    col = "abs_#{mode}_#{c}_value".to_sym
    define_method(col) { extract_from_min_max(col) }
    virtual_column col, :type => :float
  end

  Metric::Rollup::BURST_COLS.product([:min, :max]).each do |c, mode|
    col = "abs_#{mode}_#{c}_timestamp".to_sym
    define_method(col) { extract_from_min_max(col) }
    virtual_column col, :type => :datetime
  end

  def extract_from_min_max(col)
    self.min_max ||= {}
    val = self.min_max[col.to_sym]

    # HACK: for non-vmware environments, *_reserved values are 0.
    # Assume, a nil or 0 reservation means all available memory/cpu is available by using the *_available column.
    # This should really be done by subclassing where each subclass can define reservations or
    # changing the reports to allow for optional reservations.
    if val.to_i == 0 && col.to_s =~ /(.+)_reserved$/
      return send("#{$1}_available")
    else
      return val
    end
  end

  def self.latest_rollups(resource_type, resource_ids = nil, capture_interval_name = nil)
    capture_interval_name ||= "hourly"
    metrics = where(:resource_type => resource_type, :capture_interval_name => capture_interval_name)
    metrics = metrics.where(:resource_id => resource_ids) if resource_ids
    metrics = metrics.order(:resource_id, :timestamp => :desc)
    metrics.select('DISTINCT ON (metric_rollups.resource_id) metric_rollups.*')
  end

  def self.rollups_in_range(resource_type, resource_ids, capture_interval_name, start_date, end_date = nil)
    capture_interval_name ||= 'hourly'
    end_date = end_date.nil? ? Time.zone.today : end_date
    metrics = where(:resource_type         => resource_type,
                    :capture_interval_name => capture_interval_name,
                    :timestamp             => start_date.beginning_of_day...end_date.end_of_day)
    metrics = metrics.where(:resource_id => resource_ids) if resource_ids
    metrics.order(:resource_id, :timestamp => :desc)
  end

  def metering_used_fields_present?
    @metering_used_fields_present ||= METERING_USED_METRIC_FIELDS.any? { |field| send(field).present? && send(field).nonzero? }
  end
end
