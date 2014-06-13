require "NetappManageabilityAPI/NmaTypes"

module OntapMetricsRollupMixin
    extend ActiveSupport::Concern
  NON_COUNTER_COLS = [
    "id",
    "statistic_time",
    "interval",
    "queue_depth",
    "miq_storage_metric_id",
    "position",
    "created_at",
    "updated_at",
    "base_counters",
    "rollup_type",
    "time_profile_id",
    "storage_metrics_metadata_id",
    "miq_cim_instance_id"
  ]

  included { init }

  module ClassMethods
    def init
      @counterNames   = self.column_names - NON_COUNTER_COLS + self.additional_counters
      @minCounterNames  = @counterNames.dup.delete_if { |cn| !(cn =~ /.*_min$/) }
      @counterNames    -= @minCounterNames
      @maxCounterNames  = @counterNames.dup.delete_if { |cn| !(cn =~ /.*_max$/) }
      @counterNames    -= @maxCounterNames
      @rateCounterNames = nil
      @basedCounterNames  = nil
      @baseCounterNames = nil
      @metadataClass    = (self.name + "Metadata").constantize
    end

    def metadataClass
      return @metadataClass
    end

    def counterNames
      return @counterNames
    end

    def minCounterNames
      return @minCounterNames
    end

    def maxCounterNames
      return @maxCounterNames
    end

    def rateCounterNames(counterInfo)
      @rateCounterNames ||= self.counterNames.dup.delete_if { |c| counterInfo[c].properties != "rate" }
    end

    def basedCounterNames(counterInfo)
      @basedCounterNames ||= self.counterNames.dup.delete_if { |c| counterInfo[c]['base-counter'].nil? }
    end

    def baseCounterNames(counterInfo)
      return @baseCounterNames unless @baseCounterNames.nil?
      bca = []
      counterInfo.each_value do |ci|
        unless (bcn = ci['base-counter']).nil?
          bca << bcn
        end
      end
      @baseCounterNames = self.counterNames & bca
    end

    def find_all_by_interval_and_time_range(interval, start_time, end_time = nil, count = :all, options = {})
      my_cond = ["rollup_type = ? and statistic_time > ? and statistic_time <= ?", interval, start_time, end_time]

      passed_cond = options.delete(:conditions)
      options[:conditions] = passed_cond.nil? ? my_cond : "( #{self.send(:sanitize_sql_for_conditions, my_cond)} ) AND ( #{self.send(:sanitize_sql, passed_cond)} )"

      $log.debug("#{self.name}.find_all_by_interval_and_time_range: Find options: #{options.inspect}")
      self.find(count, options)
    end
  end # module ClassMethods

  def counter_info
    return nil if self.storage_metrics_metadata.nil?
    return self.storage_metrics_metadata.counter_info
  end

  #
  # Once set, counter_info will remain the same for all instances
  # of the same class.
  #
  def counter_info=(val)
    return self.counter_info unless self.counter_info.nil?
    begin
      smm = self.class.metadataClass.create!(:counter_info => val)
    rescue ActiveRecord::RecordInvalid => err
      smm = self.class.metadataClass.first
    end
    self.storage_metrics_metadata = smm
    return smm.counter_info
  end

  def counterNames
    self.class.counterNames
  end

  def minCounterNames
    self.class.minCounterNames
  end

  def maxCounterNames
    self.class.maxCounterNames
  end

  def rateCounterNames
    self.class.rateCounterNames(self.counter_info)
  end

  def basedCounterNames
    self.class.basedCounterNames(self.counter_info)
  end

  def baseCounterNames
    self.class.baseCounterNames(self.counter_info)
  end

  def counter_unit(counterName)
    raise "#{self.class.name}.counter_unit: counter #{counterName} not found" if (ci = self.counter_info[counterName]).nil?
    return ci['unit']
  end

  def counter_desc(counterName)
    raise "#{self.class.name}.counter_desc: counter #{counterName} not found" if (ci = self.counter_info[counterName]).nil?
    return ci['desc']
  end

  def hourly_rollup(rollup_time, metric_list)
    $log.info "#{self.class.name}.hourly_rollup: #{rollup_time.to_s}"
    self.statistic_time = rollup_time
    self.rollup_type  = "hourly"

    m1 = metric_list.first
    rateCounterNames  = m1.rateCounterNames
    basedCounterNames = m1.basedCounterNames
    baseCounterNames  = m1.baseCounterNames
    counterInfo     = m1.counter_info

    bcHash  = Hash.new { |h,k| h[k] = 0 }

    totInterval = 0
    metric_list.each do |metrics|
      totInterval += metrics.interval
      baseCounterNames.each { |bc| bcHash[bc] += metrics.base_counters[bc] }
    end
    self.interval   = totInterval
    self.base_counters  = bcHash

    rateCounterNames.each do |rc|
      minVal = maxVal = rcTotal = 0
      metric_list.each do |metrics|
        val = metrics[rc]
        minVal  = val if minVal > val
        maxVal  = val if maxVal < val
        rcTotal += val * metrics.interval
      end
      self[rc] = rcTotal / totInterval
      self[rc + "_min"] = minVal
      self[rc + "_max"] = maxVal
      addMinMaxCounterInfo(counterInfo, rc)
    end

    basedCounterNames.each do |bc|
      minVal = maxVal = bcTotal = 0
      baseCounterName = counterInfo[bc].base_counter
      metric_list.each do |metrics|
        val   = metrics[bc]
        minVal  = val if minVal > val
        maxVal  = val if maxVal < val
        bcTotal += val * metrics.base_counters[baseCounterName]
      end
      if (bcv = bcHash[baseCounterName]) == 0
        $log.info "#{self.class.name}.hourly_rollup: counter = #{bc}, base counter (#{baseCounterName}) is zero."
        self[bc] = 0
      else
        self[bc] = bcTotal / bcv
      end
      self[bc + "_min"] = minVal
      self[bc + "_max"] = maxVal
      addMinMaxCounterInfo(counterInfo, bc)
    end
    self.counter_info = counterInfo
  end

  def daily_rollup(rollup_time, time_profile, metric_list)
    $log.info "#{self.class.name}.daily_rollup: #{rollup_time.to_s}"
    self.statistic_time = rollup_time
    self.time_profile = time_profile
    self.rollup_type  = "daily"

    m1 = metric_list.first
    rateCounterNames  = m1.rateCounterNames
    basedCounterNames = m1.basedCounterNames
    baseCounterNames  = m1.baseCounterNames
    counterInfo     = m1.counter_info
    self.counter_info = counterInfo

    bcHash  = Hash.new { |h,k| h[k] = 0 }

    totInterval = 0
    metric_list.each do |metrics|
      totInterval += metrics.interval
      baseCounterNames.each { |bc| bcHash[bc] += metrics.base_counters[bc] }
    end
    self.interval   = totInterval
    self.base_counters  = bcHash

    rateCounterNames.each do |rc|
      rcTotal = 0
      metric_list.each { |metrics| rcTotal += metrics[rc] * metrics.interval }
      self[rc] = rcTotal / totInterval
    end

    basedCounterNames.each do |bc|
      bcTotal = 0
      baseCounterName = counterInfo[bc].base_counter
      metric_list.each { |metrics| bcTotal += metrics[bc] * metrics.base_counters[baseCounterName] }
      if (bcv = bcHash[baseCounterName]) == 0
        $log.info "#{self.class.name}.daily_rollup: counter = #{bc}, base counter (#{baseCounterName}) is zero."
        self[bc] = 0
      else
        self[bc] = bcTotal / bcv
      end
    end

    minCounterNames.each do |mc|
      minVal = 0
      metric_list.each do |metrics|
        begin
          val = metrics[mc]
          minVal = val if val < minVal
        rescue => err
          $log.error "daily_rollup: mc = #{mc} (#{metrics.class.name})"
          raise
        end
      end
      self[mc] = minVal
    end

    maxCounterNames.each do |mc|
      maxVal = 0
      metric_list.each do |metrics|
        val = metrics[mc]
        maxVal = val if val > maxVal
      end
      self[mc] = maxVal
    end
  end

  def addMinMaxCounterInfo(counterInfo, cn)
    cnMin = cn + "_min"
    cnMax = cn + "_max"
    ci = counterInfo[cn]

    counterInfo[cnMin] = NmaHash.new {
      name  cnMin
      unit  ci.unit
      desc  "Minimum value over rollup period - " + ci.desc
    }
    counterInfo[cnMax] = NmaHash.new {
      name  cnMax
      unit  ci.unit
      desc  "Maximum value over rollup period - " + ci.desc
    }
  end

  # Virtual columns for timestamp formatting as just Date or just Time
  def v_statistic_date
    self.statistic_time
  end

  def v_statistic_time
    self.statistic_time
  end

end
