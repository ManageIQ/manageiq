class MetricRollup < ApplicationRecord
  include Metric::Common
  include_concern 'Metric::ChargebackHelper'

  CHARGEBACK_METRIC_FIELDS = %w(derived_vm_numvcpus cpu_usagemhz_rate_average
                                cpu_usage_rate_average disk_usage_rate_average
                                derived_memory_available derived_memory_used
                                net_usage_rate_average derived_vm_used_disk_storage
                                derived_vm_allocated_disk_storage).freeze

  def self.with_interval_and_time_range(interval, timestamp)
    where(:capture_interval_name => interval, :timestamp => timestamp)
  end

  def self.extract_from_min_max_as_arel(col)
    lambda do |t|
      min_max_col_match = Arel::Nodes::SqlLiteral.new(%Q{"metric_rollups"."min_max" from '#{col}: ([0-9\.]+)'})
      substring_function = Arel::Nodes::NamedFunction.new("substring", [min_max_col_match])
      Arel::Nodes::NamedFunction.new("CAST", [substring_function.as("double precision")])
    end
  end

  #
  # min_max column getters
  #

  Metric::Rollup::ROLLUP_COLS.reject {|col| col.to_s =~ /(.+)_reserved$/}
                             .product([:min, :max]).compact.each do |c, mode|
    col = "#{mode}_#{c}".to_sym
    define_method(col) { extract_from_min_max_with_arel_check(col) }
    virtual_attribute col, :float, :arel => extract_from_min_max_as_arel(col)
  end

  Metric::Rollup::ROLLUP_COLS.select {|col| col.to_s =~ /(.+)_reserved$/}
                             .product([:min, :max]).compact.each do |c, mode|
    col = "#{mode}_#{c}".to_sym
    define_method(col) { extract_from_min_max_reserved(col) }
    virtual_column col, :type => :float
  end

  Metric::Rollup::BURST_COLS.product([:min, :max]).each do |c, mode|
    col = "abs_#{mode}_#{c}_value".to_sym
    define_method(col) { extract_from_min_max_with_arel_check(col) }
    virtual_attribute col, :float, :arel => extract_from_min_max_as_arel(col)
  end

  Metric::Rollup::BURST_COLS.product([:min, :max]).each do |c, mode|
    col = "abs_#{mode}_#{c}_timestamp".to_sym
    define_method(col) { extract_from_min_max(col) }
    virtual_column col, :type => :datetime
  end

  def extract_from_min_max_with_arel_check(col)
    if has_attribute?(col.to_s)
      self[col.to_s]
    else
      self.min_max ||= {}
      self.min_max[col.to_sym]
    end
  end

  def extract_from_min_max(col)
    self.min_max ||= {}
    self.min_max[col.to_sym]
  end

  # HACK: for non-vmware environments, *_reserved values are 0.
  # Assume, a nil or 0 reservation means all available memory/cpu is available by using the *_available column.
  # This should really be done by subclassing where each subclass can define reservations or
  # changing the reports to allow for optional reservations.
  def extract_from_min_max_reserved(col)
    val = extract_from_min_max(col)

    if val.to_i == 0 && col.to_s =~ /(.+)_reserved$/
      send("#{$1}_available")
    else
      val
    end
  end

  def self.latest_rollups(resource_type, resource_ids = nil, capture_interval_name = nil)
    capture_interval_name ||= "hourly"
    metrics = where(:resource_type => resource_type, :capture_interval_name => capture_interval_name)
    metrics = metrics.where(:resource_id => resource_ids) if resource_ids
    metrics = metrics.order(:resource_id, :timestamp => :desc)
    metrics.select('DISTINCT ON (metric_rollups.resource_id) metric_rollups.*')
  end

  def chargeback_fields_present?
    return @chargeback_fields_present if defined?(@chargeback_fields_present)

    @chargeback_fields_present = CHARGEBACK_METRIC_FIELDS.any? { |field| send(field).present? && send(field).nonzero? }
  end
end
