module OntapDerivedMetricMixin
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
    "storage_metrics_metadata_id",
    "miq_cim_instance_id"
  ]

  included { init }

  module ClassMethods
    def init
      @counterNames   = self.column_names - NON_COUNTER_COLS + self.additional_counters
      @rateCounterNames = nil
      @basedCounterNames  = nil
      @baseCounterNames = nil
      @metadataClass    = (self.name + "Metadata").constantize

      cfg_base = [ :storage, :metrics_collection ]
      storage_metrics_collection_interval = cfg_base + [ :collection_interval ]
      storage_metrics_max_gap_to_fill   = cfg_base + [ :max_gap_to_fill ]
      cfg = VMDB::Config.new("vmdb")
        # TODO: change to merge_from_template_if_missing() after beta.
        cfg.merge_from_template(*storage_metrics_collection_interval)
      @storageMetricsCollectionInterval = cfg.config.fetch_path(*storage_metrics_collection_interval)
      @storageMetricsCollectionInterval = @storageMetricsCollectionInterval.to_i_with_method
      cfg.merge_from_template(*storage_metrics_max_gap_to_fill)
      @storageMetricsMaxGapToFill = cfg.config.fetch_path(*storage_metrics_max_gap_to_fill)
      @storageMetricsMaxGapToFill = @storageMetricsMaxGapToFill.to_i_with_method
    end

    def metadataClass
      return @metadataClass
    end

    def counterNames
      return @counterNames
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

    def derive_metrics_common(prevMetric, curMetric, counterInfo, objectName)
      vinst0 = prevMetric[objectName].values.first
      vinst1 = curMetric[objectName].values.first

      deltaSecs = vinst1.timestamp.to_i - vinst0.timestamp.to_i

      return [] if deltaSecs < 0 || deltaSecs > @storageMetricsMaxGapToFill

      counters0 = vinst0.counters
      counters1 = vinst1.counters

      interval = @storageMetricsCollectionInterval.to_f
      nInterval = (deltaSecs / interval + 0.5).to_i
      $log.info "#{self.name}.derive_metrics_common: nIntrval = #{nInterval}"
      deltaSecs /= nInterval

      #
      # Calculate delta values for the time interval.
      #
      deltaVals = {}
      nInterval = nInterval.to_f
      counterNames.each { |cn| deltaVals[cn] = (counters1[cn].to_i - counters0[cn].to_i) / nInterval }

      statisticTime = Time.at(prevMetric.statistic_time.to_i + interval)
      nInterval = nInterval.to_i
      ra = []

      for i in 0...nInterval
        dmInst = self.new
        dmInst.derive_metrics_common(statisticTime, deltaSecs, deltaVals, counterInfo)
        ra << dmInst
        statisticTime = Time.at(statisticTime.to_i + interval)
      end

      return ra
    end
  end

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

  def rateCounterNames(counterInfo=nil)
    counterInfo = self.counter_info if counterInfo.nil?
    self.class.rateCounterNames(counterInfo)
  end

  def basedCounterNames(counterInfo=nil)
    counterInfo = self.counter_info if counterInfo.nil?
    self.class.basedCounterNames(counterInfo)
  end

  def baseCounterNames(counterInfo=nil)
    counterInfo = self.counter_info if counterInfo.nil?
    self.class.baseCounterNames(counterInfo)
  end

  def counter_unit(counterName)
    raise "#{self.class.name}.counter_unit: counter #{counterName} not found" if (ci = self.counter_info[counterName]).nil?
    return ci['unit']
  end

  def counter_desc(counterName)
    raise "#{self.class.name}.counter_desc: counter #{counterName} not found" if (ci = self.counter_info[counterName]).nil?
    return ci['desc']
  end

  def derive_metrics_common(statisticTime, deltaSecs, deltaVals, counterInfo)
    #
    # Save counterInfo for use in rollups.
    #
    self.counter_info = counterInfo

    #
    # Save interval and time information.
    #
    self.interval = deltaSecs
    self.statistic_time = statisticTime

    #
    # Save the base counter delta values.
    #
    bcHash = {}
    baseCounterNames(counterInfo).each { |bcn| bcHash[bcn] = deltaVals[bcn] }
    self.base_counters = bcHash

    #
    # Calculate and save the rates.
    #
    rateCounterNames(counterInfo).each { |rcn| self[rcn] = deltaVals[rcn].to_f / deltaSecs }

    #
    # Calculate and save based counter values.
    #
    basedCounterNames(counterInfo).each do |bcn|
      if (cdelta = deltaVals[bcn]) == 0
        self[bcn] = 0.0
        next
      end
      baseCounterName = counterInfo[bcn].base_counter
      if (bc = deltaVals[baseCounterName]) == 0
        $log.info "#{self.class.name}.derive_metrics: counter = #{bcn} (#{cdelta}), base counter (#{baseCounterName}) is zero."
        self[bcn] = 0
      else
        self[bcn] = cdelta.to_f / bc
      end
    end
  end
end
