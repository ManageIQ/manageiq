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
      @counterNames   = column_names - NON_COUNTER_COLS + additional_counters
      @rateCounterNames = nil
      @basedCounterNames  = nil
      @baseCounterNames = nil
      @metadataClass    = (name + "Metadata").constantize
    end

    def metadataClass
      @metadataClass
    end

    def counterNames
      @counterNames
    end

    def rateCounterNames(counterInfo)
      @rateCounterNames ||= counterNames.dup.delete_if { |c| counterInfo[c].properties != "rate" }
    end

    def basedCounterNames(counterInfo)
      @basedCounterNames ||= counterNames.dup.delete_if { |c| counterInfo[c]['base-counter'].nil? }
    end

    def baseCounterNames(counterInfo)
      return @baseCounterNames unless @baseCounterNames.nil?
      bca = []
      counterInfo.each_value do |ci|
        unless (bcn = ci['base-counter']).nil?
          bca << bcn
        end
      end
      @baseCounterNames = counterNames & bca
    end

    def derive_metrics_common(prevMetric, curMetric, counterInfo, objectName)
      vinst0 = prevMetric[objectName].values.first
      vinst1 = curMetric[objectName].values.first

      deltaSecs = vinst1.timestamp.to_i - vinst0.timestamp.to_i

      return [] if deltaSecs < 0 || deltaSecs > ::Settings.storage.metrics_collection.max_gap_to_fill.to_i_with_method

      counters0 = vinst0.counters
      counters1 = vinst1.counters

      interval = ::Settings.storage.metrics_collection.collection_interval.to_i_with_method.to_f
      nInterval = (deltaSecs / interval + 0.5).to_i
      _log.info "nIntrval = #{nInterval}"
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
        dmInst = new
        dmInst.derive_metrics_common(statisticTime, deltaSecs, deltaVals, counterInfo)
        ra << dmInst
        statisticTime = Time.at(statisticTime.to_i + interval)
      end

      ra
    end
  end

  def counter_info
    return nil if storage_metrics_metadata.nil?
    storage_metrics_metadata.counter_info
  end

  #
  # Once set, counter_info will remain the same for all instances
  # of the same class.
  #
  def counter_info=(val)
    return counter_info unless counter_info.nil?
    begin
      smm = self.class.metadataClass.create!(:counter_info => val)
    rescue ActiveRecord::RecordInvalid => err
      smm = self.class.metadataClass.first
    end
    self.storage_metrics_metadata = smm
    smm.counter_info
  end

  delegate :counterNames, :to => :class

  def rateCounterNames(counterInfo = nil)
    counterInfo = counter_info if counterInfo.nil?
    self.class.rateCounterNames(counterInfo)
  end

  def basedCounterNames(counterInfo = nil)
    counterInfo = counter_info if counterInfo.nil?
    self.class.basedCounterNames(counterInfo)
  end

  def baseCounterNames(counterInfo = nil)
    counterInfo = counter_info if counterInfo.nil?
    self.class.baseCounterNames(counterInfo)
  end

  def counter_unit(counterName)
    if (ci = counter_info[counterName]).nil?
      raise _("%{class_name}.counter_unit: counter %{counter_name} not found") % {:class_name   => self.class.name,
                                                                                  :counter_name => counterName}
    end
    ci['unit']
  end

  def counter_desc(counterName)
    if (ci = counter_info[counterName]).nil?
      raise _("%{class_name}.counter_desc: counter %{counter_name} not found") % {:class_name   => self.class.name,
                                                                                  :counter_name => counterName}
    end
    ci['desc']
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
        _log.info "counter = #{bcn} (#{cdelta}), base counter (#{baseCounterName}) is zero."
        self[bcn] = 0
      else
        self[bcn] = cdelta.to_f / bc
      end
    end
  end
end
