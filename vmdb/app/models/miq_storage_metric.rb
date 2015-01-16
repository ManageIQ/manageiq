require 'NetappManageabilityAPI/NmaTypes'

class MiqStorageMetric < ActiveRecord::Base
  has_one   :miq_cim_instance,
        :foreign_key => "metric_id"

  serialize :metric_obj

  ROLLUP_TYPE_HOURLY  = "hourly"
  ROLLUP_TYPE_DAILY = "daily"

  SECONDS_PER_HOUR  = 60 * 60
  SECONDS_PER_DAY   = SECONDS_PER_HOUR * 24

  def derive_metrics(curMetric, counterInfo)
    dma = self.derived_metrics_class.derive_metrics(self.metric_obj, curMetric, counterInfo)
    self.metric_obj = curMetric
    dma.each { |dm| addDerivedMetric(dm) }
    self.save
  end

  def rollup_hourly(rollup_time)
    start_time = Time.at(rollup_time.to_i - SECONDS_PER_HOUR)

    if (metric_list = derived_metrics_in_range(start_time, rollup_time)).empty?
      $log.info "#{self.class.name}.rollup_hourly: no metrics found for hourly rollup - #{rollup_time}"
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
    if self.metrics_rollup_class.nil?
      $log.info "MiqStorageMetric.hourly_rollup_by_type: no hourly rollup for subclass #{self.class.name}"
      $log.info "MiqStorageMetric.hourly_rollup_by_type: number of metrics = #{metric_list.length}"
      return
    end
    rollup_obj = self.metrics_rollup_class.new
    cn = self.class.name
    $log.info "#{cn}.hourly_rollup_by_type: hourly rollup for subclass #{cn}"
    $log.info "#{cn}.hourly_rollup_by_type: rollup_time = #{rollup_time}"
    $log.info "#{cn}.hourly_rollup_by_type: number of metrics = #{metric_list.length}"
    rollup_obj.hourly_rollup(rollup_time, metric_list)
    addMetricsRollup(rollup_obj)
  end

  def rollup_daily(rollup_time, time_profile)
    start_time = Time.at(rollup_time.to_i - SECONDS_PER_DAY)

    if (metric_list = metrics_rollups_in_range(ROLLUP_TYPE_HOURLY, start_time, rollup_time)).empty?
      $log.info "#{self.class.name}.rollup_daily: no metrics found for daily rollup - #{rollup_time}"
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
    if self.metrics_rollup_class.nil?
      $log.info "MiqStorageMetric.daily_rollup_by_type: no daily rollup for subclass #{self.class.name}"
      $log.info "MiqStorageMetric.daily_rollup_by_type: number of metrics = #{metric_list.length}"
      return
    end
    rollup_obj = self.metrics_rollup_class.new
    cn = self.class.name
    $log.info "#{cn}.daily_rollup_by_type: daily rollup for subclass #{cn}"
    $log.info "#{cn}.daily_rollup_by_type: rollup_time = #{rollup_time}, TZ = #{time_profile.tz}"
    $log.info "#{cn}.daily_rollup_by_type: number of metrics = #{metric_list.length}"
    rollup_obj.daily_rollup(rollup_time, time_profile, metric_list)
    addMetricsRollup(rollup_obj)
  end

  def derived_metrics_in_range(start_time, end_time)
    cond = [ "statistic_time >= ? AND statistic_time < ?", start_time, end_time ]
    self.miq_derived_metrics.where(cond).to_a
  end

  def metrics_rollups_in_range(rollupType, start_time, end_time)
    cond = [ "rollup_type = ? AND statistic_time >= ? AND statistic_time < ?",
         rollupType, start_time, end_time ]
    self.miq_metrics_rollups.where(cond).to_a
  end

  def metrics_rollups_by_statistic_time(rollupType, statistic_time)
    cond = [ "rollup_type = ? AND statistic_time = ?", rollupType, statistic_time ]
    self.miq_metrics_rollups.where(cond).to_a
  end

  def metrics_rollups_by_rollup_type(rollupType)
    cond = [ "rollup_type = ?", rollupType ]
    self.miq_metrics_rollups.where(cond).to_a
  end

  def addDerivedMetric(derivedMetrics)
    self.miq_derived_metrics << derivedMetrics
    self.save
    derivedMetrics.miq_cim_instance = self.miq_cim_instance
    derivedMetrics.save
  end

  def addMetricsRollup(metricsRollup)
    self.miq_metrics_rollups << metricsRollup
    self.save
    metricsRollup.miq_cim_instance = self.miq_cim_instance
    metricsRollup.save
  end

  #
  # Purging
  #

  def self.purge_window_size
    VMDB::Config.new("vmdb").config.fetch_path(:storage, :metrics_history, :purge_window_size) || 100
  end

  def self.purge_date(type)
    cfg = VMDB::Config.new("vmdb")
    vpath = [ :storage, :metrics_history, type.to_sym ]
    # TODO: change to merge_from_template_if_missing() after beta.
      cfg.merge_from_template(*vpath)
    value = cfg.config.fetch_path(*vpath)
    return nil if value.nil?

    value = value.to_i.days if value.kind_of?(Fixnum) # Default unit is days
    value = value.to_i_with_method.ago.utc unless value.nil?
    return value
  end

  def self.derived_metrics_count_by_date(older_than)
    return metrics_count_by_date(older_than, self.derived_metrics_classes)
    end

  def self.metrics_rollups_count_by_date(older_than)
    return metrics_count_by_date(older_than, self.metrics_rollup_classes)
    end

  def self.metrics_count_by_date(older_than, metrics_classes)
    count = 0
    metrics_classes.each do |mc|
      conditions = mc.arel_table[:statistic_time].lt(older_than)
      count += mc.where(conditions).count
    end
    return count
  end
  private_class_method :metrics_count_by_date

  def self.purge_all_timer
    purge_derived_metrics_by_date(purge_date(:keep_realtime_metrics) || 4.hours.ago.utc)
    purge_hourly_metrics_rollups_by_date(purge_date(:keep_hourly_metrics) || 6.months.ago.utc)
    purge_daily_metrics_rollups_by_date(purge_date(:keep_daily_metrics) || 6.months.ago.utc)
  end

  def self.purge_derived_metrics_by_date(older_than, window = nil)
    log_header = "MIQ(#{self.name}.purge_derived_metrics_by_date)"
    $log.info "#{log_header} Purging derived metrics older than [#{older_than}]..."
    gtotal = purge(older_than, nil, window, self.derived_metrics_classes)
    $log.info "#{log_header} Purging derived metrics older than [#{older_than}]...Complete - Deleted #{gtotal} records"
    return nil
  end

  def self.purge_hourly_metrics_rollups_by_date(older_than, window = nil)
    log_header = "MIQ(#{self.name}.purge_metrics_rollups_by_date)"
    $log.info "#{log_header} Purging hourly metrics rollups older than [#{older_than}]..."
    gtotal = purge(older_than, ROLLUP_TYPE_HOURLY, window, self.metrics_rollup_classes)
    $log.info "#{log_header} Purging hourly metrics rollups older than [#{older_than}]...Complete - Deleted #{gtotal} records"
    return nil
  end

  def self.purge_daily_metrics_rollups_by_date(older_than, window = nil)
    log_header = "MIQ(#{self.name}.purge_metrics_rollups_by_date)"
    $log.info "#{log_header} Purging daily metrics rollups older than [#{older_than}]..."
    gtotal = purge(older_than, ROLLUP_TYPE_DAILY, window, self.metrics_rollup_classes)
    $log.info "#{log_header} Purging daily metrics rollups older than [#{older_than}]...Complete - Deleted #{gtotal} records"
    return nil
  end

  def self.purge(older_than, rollup_type, window, metrics_classes)
    log_header = "MIQ(#{self.name}.purge)"
    window ||= purge_window_size
    gtotal = 0
    metrics_classes.each do |mc|
      conditions = mc.arel_table[:statistic_time].lt(older_than)
      query = mc.select(:id).where(conditions)
      query = query.where(:rollup_type => rollup_type) unless rollup_type.nil?
      total = 0
      query.find_in_batches(:batch_size => window) do |ma|
        ids = ma.collect { |m| m.id }
        total += mc.delete_all(:id => ids)
      end
      gtotal += total
      $log.info "#{log_header} Purged #{total} records from #{mc.name} table."
    end
    return gtotal
  end
  private_class_method :purge

  #
  # The names of instantiated classes that are subclasses of MiqStorageMetric.
  # Called directly from MiqStorageMetric.
  #
  def self.sub_class_names
    self.select('DISTINCT type').collect { |c| c.type }
  end

  #
  # The instantiated classes that are subclasses of MiqStorageMetric.
  # Called directly from MiqStorageMetric.
  #
  def self.sub_classes
    self.select('DISTINCT type').collect { |c| c.type.constantize }
  end

  #
  # The names of the derived metrics classes for the instantiated subclasses.
  # Called directly from MiqStorageMetric.
  #
  def self.derived_metrics_class_names
    self.select('DISTINCT type').collect { |c| c.type.constantize.derived_metrics_class_name }
  end

  #
  # The derived metrics classes for the instantiated subclasses.
  # Called directly from MiqStorageMetric.
  #
  def self.derived_metrics_classes
    self.select('DISTINCT type').collect { |c| c.type.constantize.derived_metrics_class_name.constantize }
  end

  #
  # The names of the metrics rollup classes for the instantiated subclasses.
  # Called directly from MiqStorageMetric.
  #
  def self.metrics_rollup_class_names
    self.select('DISTINCT type').collect { |c| c.type.constantize.metrics_rollup_class_name }
  end

  #
  # The metrics rollup classes for the instantiated subclasses.
  # Called directly from MiqStorageMetric.
  #
  def self.metrics_rollup_classes
    self.select('DISTINCT type').collect { |c| c.type.constantize.metrics_rollup_class_name.constantize }
  end

  #
  # The name of the derived metrics class for this subclass.
  # Called from subclass of MiqStorageMetric.
  # Constant defined in subclass.
  #
  def self.derived_metrics_class_name
    return nil unless self.const_defined?(:DERIVED_METRICS_CLASS_NAME)
    return self::DERIVED_METRICS_CLASS_NAME
  end

  #
  # The derived metrics class for this subclass.
  # Called from subclass of MiqStorageMetric.
  #
  def self.derived_metrics_class
    return nil if self.derived_metrics_class_name.nil?
    return self.derived_metrics_class_name.constantize
  end

  #
  # The derived metrics class for this subclass.
  # Called from an instance of subclass of MiqStorageMetric.
  #
  def derived_metrics_class
    return self.class.derived_metrics_class
  end

  #
  # The name of the metrics rollup class for this subclass.
  # Called from subclass of MiqStorageMetric.
  # Constant defined in subclass.
  #
  def self.metrics_rollup_class_name
    return nil unless self.const_defined?(:METRICS_ROLLUP_CLASS_NAME)
    return self::METRICS_ROLLUP_CLASS_NAME
  end

  #
  # The metrics rollup class for this subclass.
  # Called from subclass of MiqStorageMetric.
  #
  def self.metrics_rollup_class
    return nil if self.metrics_rollup_class_name.nil?
    return self.metrics_rollup_class_name.constantize
  end

  #
  # The metrics rollup class for this subclass.
  # Called from an instance of subclass of MiqStorageMetric.
  #
  def metrics_rollup_class
    return self.class.metrics_rollup_class
  end
end
