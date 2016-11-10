require 'net_app_manageability/types'

class MiqStorageMetric < ApplicationRecord
  has_one   :miq_cim_instance,
            :foreign_key => "metric_id"

  serialize :metric_obj

  ROLLUP_TYPE_HOURLY  = "hourly"
  ROLLUP_TYPE_DAILY = "daily"

  SECONDS_PER_HOUR  = 60 * 60
  SECONDS_PER_DAY   = SECONDS_PER_HOUR * 24

  def derive_metrics(curMetric, counterInfo)
    dma = derived_metrics_class.derive_metrics(metric_obj, curMetric, counterInfo)
    self.metric_obj = curMetric
    dma.each { |dm| addDerivedMetric(dm) }
    save
  end

  def rollup_hourly(rollup_time)
    start_time = Time.at(rollup_time.to_i - SECONDS_PER_HOUR)

    if (metric_list = derived_metrics_in_range(start_time, rollup_time)).empty?
      _log.info "no metrics found for hourly rollup - #{rollup_time}"
      return
    end

    #
    # Check for contiguous missing hourly rollups and roll them up first.
    #
    if metrics_rollups_by_statistic_time(ROLLUP_TYPE_HOURLY, start_time).first.nil?
      rollup_hourly(start_time)
    end

    hourly_rollup_by_type(rollup_time, metric_list)
  end

  def hourly_rollup_by_type(rollup_time, metric_list)
    if metrics_rollup_class.nil?
      _log.info "no hourly rollup for subclass #{self.class.name}"
      _log.info "number of metrics = #{metric_list.length}"
      return
    end
    rollup_obj = metrics_rollup_class.new
    _log.info "hourly rollup for subclass #{self.class.name}"
    _log.info "rollup_time = #{rollup_time}"
    _log.info "number of metrics = #{metric_list.length}"
    rollup_obj.hourly_rollup(rollup_time, metric_list)
    addMetricsRollup(rollup_obj)
  end

  def rollup_daily(rollup_time, time_profile)
    start_time = Time.at(rollup_time.to_i - SECONDS_PER_DAY)

    if (metric_list = metrics_rollups_in_range(ROLLUP_TYPE_HOURLY, start_time, rollup_time)).empty?
      _log.info "no metrics found for daily rollup - #{rollup_time}"
      return
    end

    #
    # Check for contiguous missing daily rollups and roll them up first.
    #
    if metrics_rollups_by_statistic_time(ROLLUP_TYPE_DAILY, start_time).first.nil?
      rollup_daily(start_time, time_profile)
    end

    daily_rollup_by_type(rollup_time, time_profile, metric_list)
  end

  def daily_rollup_by_type(rollup_time, time_profile, metric_list)
    if metrics_rollup_class.nil?
      _log.info "no daily rollup for subclass #{self.class.name}"
      _log.info "number of metrics = #{metric_list.length}"
      return
    end
    rollup_obj = metrics_rollup_class.new
    _log.info "daily rollup for subclass #{self.class.name}"
    _log.info "rollup_time = #{rollup_time}, TZ = #{time_profile.tz}"
    _log.info "number of metrics = #{metric_list.length}"
    rollup_obj.daily_rollup(rollup_time, time_profile, metric_list)
    addMetricsRollup(rollup_obj)
  end

  def derived_metrics_in_range(start_time, end_time)
    miq_derived_metrics.where(:statistic_time => start_time...end_time).to_a
  end

  def metrics_rollups_in_range(rollup_type, start_time, end_time)
    where(:rollup_type => rollup_type, :statistic_time => start_time...end_time).to_a
  end

  def metrics_rollups_by_statistic_time(rollup_type, statistic_time)
    miq_metrics_rollups.where(:rollup_type => rollup_type, :statistic_time => statistic_time).to_a
  end

  def metrics_rollups_by_rollup_type(rollup_type)
    miq_metrics_rollups.where(:rollup_type => rollup_type).to_a
  end

  def addDerivedMetric(derivedMetrics)
    miq_derived_metrics << derivedMetrics
    save
    derivedMetrics.miq_cim_instance = miq_cim_instance
    derivedMetrics.save
  end

  def addMetricsRollup(metricsRollup)
    miq_metrics_rollups << metricsRollup
    save
    metricsRollup.miq_cim_instance = miq_cim_instance
    metricsRollup.save
  end

  #
  # Purging
  #

  def self.purge_window_size
    ::Settings.storage.metrics_history.purge_window_size
  end

  def self.purge_date(type)
    value = ::Settings.storage.metrics_history[type]
    return nil if value.nil?

    value = value.to_i.days if value.kind_of?(Fixnum) # Default unit is days
    value = value.to_i_with_method.seconds.ago.utc
    value
  end

  def self.derived_metrics_count_by_date(older_than)
    metrics_count_by_date(older_than, derived_metrics_classes)
  end

  def self.metrics_rollups_count_by_date(older_than)
    metrics_count_by_date(older_than, metrics_rollup_classes)
  end

  def self.metrics_count_by_date(older_than, metrics_classes)
    metrics_classes.collect do |mc|
      mc.where(mc.arel_table[:statistic_time].lt(older_than)).count
    end.sum
  end
  private_class_method :metrics_count_by_date

  def self.purge_all_timer
    purge_derived_metrics_by_date(purge_date(:keep_realtime_metrics))
    purge_hourly_metrics_rollups_by_date(purge_date(:keep_hourly_metrics))
    purge_daily_metrics_rollups_by_date(purge_date(:keep_daily_metrics))
  end

  def self.purge_derived_metrics_by_date(older_than, window = nil)
    _log.info "Purging derived metrics older than [#{older_than}]..."
    gtotal = purge(older_than, nil, window, derived_metrics_classes)
    _log.info "Purging derived metrics older than [#{older_than}]...Complete - Deleted #{gtotal} records"
    nil
  end

  def self.purge_hourly_metrics_rollups_by_date(older_than, window = nil)
    _log.info "Purging hourly metrics rollups older than [#{older_than}]..."
    gtotal = purge(older_than, ROLLUP_TYPE_HOURLY, window, metrics_rollup_classes)
    _log.info "Purging hourly metrics rollups older than [#{older_than}]...Complete - Deleted #{gtotal} records"
    nil
  end

  def self.purge_daily_metrics_rollups_by_date(older_than, window = nil)
    _log.info "Purging daily metrics rollups older than [#{older_than}]..."
    gtotal = purge(older_than, ROLLUP_TYPE_DAILY, window, metrics_rollup_classes)
    _log.info "Purging daily metrics rollups older than [#{older_than}]...Complete - Deleted #{gtotal} records"
    nil
  end

  def self.purge(older_than, rollup_type, window, metrics_classes)
    window ||= purge_window_size
    metrics_classes.map do |mc|
      query = mc.where(mc.arel_table[:statistic_time].lt(older_than))
      query = query.where(:rollup_type => rollup_type) unless rollup_type.nil?
      query.delete_in_batches(window).tap do |total|
        _log.info "Purged #{total} records from #{mc.name} table."
      end
    end.sum
  end
  private_class_method :purge

  #
  # The names of instantiated classes that are subclasses of MiqStorageMetric.
  # Called directly from MiqStorageMetric.
  #
  def self.sub_class_names
    distinct.pluck(:type)
  end

  #
  # The instantiated classes that are subclasses of MiqStorageMetric.
  # Called directly from MiqStorageMetric.
  #
  def self.sub_classes
    sub_class_names.map(&:constantize)
  end

  #
  # The names of the derived metrics classes for the instantiated subclasses.
  # Called directly from MiqStorageMetric.
  #
  def self.derived_metrics_class_names
    sub_classes.map(&:derived_metrics_class_name)
  end

  #
  # The derived metrics classes for the instantiated subclasses.
  # Called directly from MiqStorageMetric.
  #
  def self.derived_metrics_classes
    derived_metrics_class_names.map(&:constantize)
  end

  #
  # The names of the metrics rollup classes for the instantiated subclasses.
  # Called directly from MiqStorageMetric.
  #
  def self.metrics_rollup_class_names
    sub_classes.map(&:metrics_rollup_class_name).compact
  end

  #
  # The metrics rollup classes for the instantiated subclasses.
  # Called directly from MiqStorageMetric.
  #
  def self.metrics_rollup_classes
    metrics_rollup_class_names.map(&:constantize)
  end

  #
  # The name of the derived metrics class for this subclass.
  # Called from subclass of MiqStorageMetric.
  # Constant defined in subclass.
  #
  def self.derived_metrics_class_name
    self::DERIVED_METRICS_CLASS_NAME if self.const_defined?(:DERIVED_METRICS_CLASS_NAME)
  end

  #
  # The derived metrics class for this subclass.
  # Called from subclass of MiqStorageMetric.
  #
  def self.derived_metrics_class
    derived_metrics_class_name.try!(:constantize)
  end

  #
  # The derived metrics class for this subclass.
  # Called from an instance of subclass of MiqStorageMetric.
  #
  delegate :derived_metrics_class, :to => :class

  #
  # The name of the metrics rollup class for this subclass.
  # Called from subclass of MiqStorageMetric.
  # Constant defined in subclass.
  #
  def self.metrics_rollup_class_name
    self::METRICS_ROLLUP_CLASS_NAME if self.const_defined?(:METRICS_ROLLUP_CLASS_NAME)
  end

  #
  # The metrics rollup class for this subclass.
  # Called from subclass of MiqStorageMetric.
  #
  def self.metrics_rollup_class
    metrics_rollup_class_name.try!(:constantize)
  end

  #
  # The metrics rollup class for this subclass.
  # Called from an instance of subclass of MiqStorageMetric.
  #
  delegate :metrics_rollup_class, :to => :class
end
