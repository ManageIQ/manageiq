module VimPerformanceAnalysis
  class Planning
    include Vmdb::Logging
    attr_accessor :options, :vm
    attr_reader   :compute, :storage

    def initialize(vm, options = {})
      # Options
      #   :userid       => User ID of requesting user for RBAC
      #   :targets      => Defines explicit target Cluster or Host and Datastore - mutually exclusive with :target_tags
      #     :compute      => Target cluster/host
      #     :storage      => Target storage
      #   :target_tags  => Defines tags that will be used to select targets - mutually exclusive with :targets
      #     :compute_filter => MiqSearch instance of id
      #     :compute_type   => :EmsCluster || :Host - Select host or cluster as target
      #     :compute_tags   => Array of arrays of management tags used for selecting targets. inner array elements are 'And'ed, outter arrays are 'OR'ed
      #                        Example: [["/managed/department/accounting", "/managed/department/automotive"], ["/managed/environment/prod"], ["/managed/function/desktop"]]
      #     :storage_filter => MiqSearch instance of id
      #     :storage_tags   => Same as above for storage selection only
      #
      #   :range        => Trend calculation options
      #     :days         => Number of days back from daily_date
      #     :end_date     => Ending date
      #
      #   :vm_options =>
      #     :cpu    =>
      #       :mode   => :perf_trend (:perf_trend - Trend of perf data | :perf_latest - Perf data last row in range| :current - directly from object)
      #       :metric => :max_cpu_usage_rate_average
      #     :memory =>
      #       :mode   => :perf_trend (:perf_trend | :perf_latest | :current)
      #       :metric => :max_mem_usage_absolute_average
      #     :storage =>
      #       :mode   => :current (:perf_trend | :perf_latest | :current)
      #       :metric => :used_disk_storage | :allocated_disk_storage
      #
      #   :target_options => Absence of one of the sub-hashes implies that key (:cpu, :memory, :storage) should not be used in calculation.
      #     :cpu     =>
      #       :mode       => :perf_trend (:perf_trend | :perf_latest | :current)
      #       :metric     => :max_cpu_usage_rate_average
      #       :limit_col  => :derived_cpu_available
      #       :limit_pct  => 90
      #     :memory  =>
      #       :mode       => :perf_trend (:perf_trend | :perf_latest | :current)
      #       :metric     => :max_mem_usage_absolute_average
      #       :limit_col  => :derived_memory_available
      #       :limit_pct  => 90
      #     :storage =>
      #       :mode       => :current (:perf_trend | :perf_latest | :current)
      #       :metric     => :v_used_space
      #       :limit_col  => :total_space
      #       :limit_pct  => 80

      @vm = vm
      @options = options

      get_targets
    end

    def get_targets
      if @options[:targets]
        @compute = Array.wrap(@options[:targets][:compute])
        @storage = Array.wrap(@options[:targets][:storage])
      elsif @options[:target_tags]
        topts = @options[:target_tags]
        includes = {:hardware => {}, :vms => {:hardware => {}}} if topts[:compute_type].to_sym == :Host
        search_options = {
          :class            => topts[:compute_type].to_s,
          :include_for_find => includes,
          :references       => includes,
          :userid           => @options[:userid],
          :miq_group_id     => @options[:miq_group_id],
        }
        if topts[:compute_filter]
          search = if topts[:compute_filter].kind_of?(MiqSearch)
                     topts[:compute_filter]
                   else
                     MiqSearch.find(topts[:compute_filter])
                   end
          search_options[:filter] = search.filter
        elsif topts[:compute_tags]
          search_options[:tag_filters] = {"managed" => topts[:compute_tags]}
        end
        @compute = Rbac.filtered(nil, search_options)

        MiqPreloader.preload(@compute, :storages)
        stores = @compute.collect { |c| storages_for_compute_target(c) }.flatten.uniq

        filter_options = {:class => Storage, :userid => @options[:userid], :miq_group_id => @options[:miq_group_id]}
        if topts[:storage_filter]
          search = if topts[:storage_filter].kind_of?(MiqSearch)
                     topts[:storage_filter]
                   else
                     MiqSearch.find(topts[:storage_filter])
                   end
          filter_options[:filter] = search.filter
        elsif topts[:storage_tags]
          filter_options[:tag_filters] = {"managed" => topts[:storage_tags]}
        end
        @storage = Rbac.filtered(stores, filter_options)
      end
      return @compute, @storage
    end

    def storages_for_compute_target(target)
      return target.storages if target.kind_of?(Host)

      if target.kind_of?(EmsCluster)
        return target.hosts.collect(&:storages).flatten.compact
      else
        raise _("unable to get storages for %{name}") % {:name => target.class}
      end
    end

    VM_CONSUMES_METRIC_DEFAULT = {
      :cpu     => {
        :used      => {:metric => :max_cpu_usagemhz_rate_average, :mode => :perf_trend},
        :reserved  => {:metric => :cpu_reserve, :mode => :current},
        :allocated => nil,
        :manual    => {:value =>  nil, :mode => :manual}
      },
      :vcpus   => {
        :used      => {:metric => :num_cpu, :mode => :current},
        :reserved  => {:metric => :num_cpu, :mode => :current},
        :allocated => {:metric => :num_cpu, :mode => :current},
        :manual    => {:value =>  nil, :mode => :manual}
      },
      :memory  => {
        :used      => {:metric => :max_derived_memory_used, :mode => :perf_trend},
        :reserved  => {:metric => :memory_reserve, :mode => :current},
        :allocated => {:metric => :ram_size, :mode => :current},
        :manual    => {:value =>  nil, :mode => :manual}
      },
      :storage => {
        :used      => {:metric => :used_disk_storage, :mode => :current},
        :reserved  => {:metric => :provisioned_storage, :mode => :current},
        :allocated => {:metric => :allocated_disk_storage, :mode => :current},
        :manual    => {:value =>  nil, :mode => :manual}
      }
    }
    ##########################################################
    #   :vm_options =>
    #     :cpu    =>
    #       :mode   => :perf_trend (:perf_trend - Trend of perf data | :perf_latest - Perf data last row in range| :current - directly from object)
    #       :metric => :max_cpu_usage_rate_average
    #     :memory =>
    #       :mode   => :perf_trend (:perf_trend | :perf_latest | :current)
    #       :metric => :max_mem_usage_absolute_average
    #     :storage =>
    #       :mode   => :current (:perf_trend | :perf_latest | :current)
    #       :metric => :used_disk_storage | :allocated_disk_storage
    ##########################################################
    def get_vm_needs
      options = @options

      if VimPerformanceAnalysis.needs_perf_data?(options[:vm_options])
        perf_cols = [:cpu, :vcpus, :memory, :storage].collect { |t| options.fetch_path(:vm_options, t, :metric) }.compact
      end

      vm_perf = VimPerformanceAnalysis.get_daily_perf(@vm, options[:range], options[:ext_options], perf_cols)
      vm_ts = vm_perf.last.timestamp unless vm_perf.blank?
      [:cpu, :vcpus, :memory, :storage].each_with_object({}) do |type, vm_needs|
        vm_needs[type] = vm_consumes(vm_perf, vm_ts, options[:vm_options][type], type)
      end
    end

    def vm_consumes(perf, ts, options, type, vm = @vm)
      return nil if options.nil?

      options[:metric] ||= VM_CONSUMES_METRIC_DEFAULT[type][:used][:metric]
      options[:mode] ||= VM_CONSUMES_METRIC_DEFAULT[type][:used][:metric]

      return options[:value] if options[:mode] == :manual

      measure_object(vm, options[:mode], options[:metric], perf, ts, type)
    end

    COMPUTE_OFFERS_MODE_DEFAULT = {
      :cpu     => :perf_trend,
      :memory  => :perf_trend,
      :storage => :current
    }

    COMPUTE_OFFERS_METRIC_DEFAULT = {
      :cpu     => :max_cpu_usagemhz_rate_average,
      :memory  => :max_derived_memory_used,
      :storage => :v_used_space
    }

    COMPUTE_OFFERS_RESERVE_METRIC_DEFAULT = {
      :cpu    => :total_vm_cpu_reserve,
      :memory => :total_vm_memory_reserve,
    }

    COMPUTE_OFFERS_LIMIT_COL_DEFAULT = {
      :cpu     => :derived_cpu_available,
      :memory  => :derived_memory_available,
      :storage => :total_space
    }

    COMPUTE_OFFERS_LIMIT_PCT_DEFAULT = {
      :cpu     => 90,
      :memory  => 90,
      :storage => 80
    }

    ##########################################################
    #   :target_options => Absence of one of the sub-hashes implies that key (:cpu, :memory, :storage) should not be used in calculation.
    #     :cpu     =>
    #       :mode       => :perf_trend (:perf_trend | :perf_latest | :current)
    #       :metric     => :max_cpu_usage_rate_average
    #       :limit_col  => :derived_cpu_available
    #       :limit_pct  => 90
    #     :vcpus   =>
    #       :mode       => :current (:perf_trend | :perf_latest | :current)
    #       :metric     => Not applicable
    #       :limit_col  => Not applicable
    #       :limit_ratio => 20
    #     :memory  =>
    #       :mode       => :perf_trend (:perf_trend | :perf_latest | :current)
    #       :metric     => :max_mem_usage_absolute_average
    #       :limit_col  => :derived_memory_available
    #       :limit_pct  => 90
    #     :storage =>
    #       :mode       => :current (:perf_trend | :perf_latest | :current)
    #       :metric     => :v_used_space
    #       :limit_col  => :total_space
    #       :limit_pct  => 80
    ##########################################################
    def offers(perf, ts, options, type, target)
      return nil if options.nil?

      options[:mode] ||= COMPUTE_OFFERS_MODE_DEFAULT[type]
      options[:metric] ||= COMPUTE_OFFERS_METRIC_DEFAULT[type]
      options[:reserve] ||= COMPUTE_OFFERS_RESERVE_METRIC_DEFAULT[type]
      options[:limit_col] ||= COMPUTE_OFFERS_LIMIT_COL_DEFAULT[type]
      options[:limit_pct] ||= COMPUTE_OFFERS_LIMIT_PCT_DEFAULT[type]

      if type == :vcpus
        # Example:
        # cores = 5
        # total_vcpus = 20
        # limit_ratio = 10
        # vcpus_per_core = (total_vcpus / cores) => 20 / 5 = 4
        # avail = (limit_ratio - vcpus_per_core) * cores => (10 - 4) * 5 = 30
        usage   = 0
        reserve = 0
        avail   = (options[:limit_ratio] - target.vcpus_per_core) * target.total_vcpus
      else
        usage   = measure_object(target, options[:mode], options[:metric],    perf, ts, type) || 0
        reserve = measure_object(target, :current,       options[:reserve],   perf, ts, type) || 0
        avail   = measure_object(target, options[:mode], options[:limit_col], perf, ts, type) || 0
        avail   = (avail * (options[:limit_pct] / 100.0)) unless avail.nil? || options[:limit_pct].blank?
      end
      usage = (usage > reserve) ? usage : reserve # Take the greater of usage or total reserve of child VMs
      [avail, usage]
    end

    def can_fit(avail, usage, need)
      return nil if avail.nil? || usage.nil? || need.nil?
      return 0   unless avail > usage && need > 0
      fits = (avail - usage) / need
      fits.truncate
    end

    def measure_object(obj, mode, col, perf, ts, type)
      return 0 if col.nil?

      case mode
      when :current
        obj.send(col)
      when :perf_trend
        VimPerformanceAnalysis.calc_trend_value_at_timestamp(perf, col, ts)
      else
        raise _("Unsupported Mode (%{mode}) for %{class} %{type} options") % {:mode  => mode,
                                                                              :class => obj.class,
                                                                              :type  => type}
      end
    end

    def vm_recommended_targets
      # This method answers C&U Planning question 3

      # Returns a hash with 2 keys - :recommendations and :errors
      #   :recommendations => [ Array of hashes each containing a recomended pair of Host or Cluster and Datastore and the number of VMs that fit
      #     :cluster   => Recommended target cluster - mutually exclusive with :host
      #     :host      => Recommended target host - mutually exclusive with :cluster
      #     :datastore => Recommended target datastore
      #     :vm_count  => Count of instances of VM that fit ]
      #   :errors    => Array of user friendly error messages if any errors are encountered

      # Return mocked up result for now
      hash = {:datastore => Storage.first, :vm_count => 42}
      if options[:target_tags][:type] == :cluster
        hash[:cluster] = EmsCluster.first
      else
        hash[:host] = Host.first
      end
      {:recomendations => [hash], :errors => nil}
    end
  end # class Planning

  # Helper methods

  def self.needs_perf_data?(options)
    options.values.detect { |v| v && v[:mode] == :perf_trend }
  end

  def self.find_perf_for_time_period(obj, interval_name, options = {})
    # Options
    #   :days        => Number of days back from end_date. Used only if start_date not passed
    #   :start_date  => Starting date
    #   :end_date    => Ending date
    #   :conditions  => ActiveRecord find conditions
    ext_options = options[:ext_options] || {}
    Metric::Helper.find_for_interval_name(interval_name, ext_options[:time_profile] || ext_options[:tz],
                                          ext_options[:class])
                  .where(:timestamp => Metric::Helper.time_range_from_hash(options), :resource => obj)
                  .where(options[:conditions]).order("timestamp")
                  .select(options[:select])
  end

  # @param obj base object
  # @param interval_name
  # @option options :days        [Numeric] Number of days back from end_date. Used to derive start_date (if not passed)
  # @option options :start_date  [Date] Starting date (typically not passed)
  # @option options :end_date    [Date] Ending date
  # @option options :select      [String|Array] Active record list of columns to bring back
  # @option options :conditions  [String|Hash|nil]
  # @option options[:ext_options] :time_profile [TimeProfile]
  # @option options[:ext_options] :tz [String] timezone used to derive time_profile (if not passed)
  def self.find_child_perf_for_time_period(obj, interval_name, options = {})
    ext_options = options[:ext_options] || {}
    rel = Metric::Helper.find_for_interval_name(interval_name, ext_options[:time_profile] || ext_options[:tz],
                                                ext_options[:class])
    case obj
    when MiqEnterprise, MiqRegion then
      rel = rel.where(:resource => obj.storages).or(rel.where(:resource => obj.ext_management_systems))
    when Host then
      rel = rel.where(:parent_host_id => obj.id)
    when EmsCluster
      rel = rel.where(:parent_ems_cluster_id => obj.id)
    when Storage then
      rel = rel.where(:parent_storage_id => obj.id)
    when ExtManagementSystem then
      rel = rel.where(:parent_ems_id => obj.id).where(:resource_type => %w(Host EmsCluster))
    else
      raise _("unknown object type: %{class}") % {:class => obj.class}
    end

    rel.where(options[:conditions]).select(options[:select])
       .where(:timestamp => Metric::Helper.time_range_from_hash(options)).to_a
  end

  # @params obj base object
  # @params interval_name (currently only 'daily')
  # @opts options :end_date [Date] end_date
  # @opts options :days     [Numeric] Number of days back from daily_date
  # @opts options :ext_options [Hash] :tz and :time_profile
  # @returns [Hash<String,String>] environment name and corresponding tags
  #   "Host/environment/prod" => "Host: Environment: Production",
  #   "Host/environment/dev"  => "Host: Environment: Development"
  def self.child_tags_over_time_period(obj, interval_name, options = {})
    classifications = Classification.hash_all_by_type_and_name

    find_child_perf_for_time_period(obj, interval_name, options.merge(:conditions => "resource_type != 'VmOrTemplate' AND tag_names IS NOT NULL", :select => "resource_type, tag_names")).inject({}) do |h, p|
      p.tag_names.split("|").each do |t|
        next if t.starts_with?("power_state")
        tag = "#{p.resource_type}/#{t}"
        next if h.key?(tag)

        c, e = t.split("/")
        cat = classifications.fetch_path(c, :category)
        cat_desc = cat.nil? ? c.titleize : cat.description
        ent = cat && classifications.fetch_path(c, :entry, e)
        ent_desc = ent.nil? ? e.titleize : ent.description
        h[tag] = "#{ui_lookup(:model => p.resource_type)}: #{cat_desc}: #{ent_desc}"
      end
      h
    end
  end

  def self.group_perf_by_timestamp(obj, perfs, cols = nil)
    cols ||= Metric::Rollup::ROLLUP_COLS

    result = {}
    counts = {}
    perf_klass = nil

    perfs.each do |p|
      perf_klass ||= p.class
      key = p.timestamp
      result[key] ||= {}
      counts[key] ||= {}
      result[key][:timestamp] = key
      result[key][:capture_interval_name] = p.capture_interval_name
      result[key][:capture_interval] = p.capture_interval
      result[key][:resource_type] = obj.class.base_class.name
      result[key][:resource_id] = obj.id
      result[key][:resource_name] = obj.name

      cols.each do |col|
        c = col.to_sym
        next unless p.respond_to?(c) && p.send(c).kind_of?(Float)

        result[key][c] ||= 0
        counts[key][c] ||= 0

        Metric::Aggregation::Aggregate.column(c, nil, result[key], counts[key], p.send(c), :average)
      end
    end

    result.each do |_k, h|
      h[:min_max] = h.keys.find_all { |k| k.to_s.starts_with?("min", "max") }.inject({}) do |mm, k|
        val = h.delete(k)
        mm[k] = val unless val.nil?
        mm
      end
      h.reject! { |k, _v| perf_klass.virtual_attribute?(k) }
    end

    result.inject([]) do |recs, k|
      _ts, v = k
      cols.each do |c|
        next unless v[c].kind_of?(Float)
        Metric::Aggregation::Process.column(c, nil, v, counts[k], true, :average)
      end

      recs.push(perf_klass.new(v))
      recs
    end
  end

  def self.calc_slope_from_data(recs, x_attr, y_attr)
    recs = recs.sort_by { |r| r.send(x_attr) } if recs.first.respond_to?(x_attr)

    coordinates = recs.each_with_object([]) do |r, arr|
      next unless r.respond_to?(x_attr) && r.respond_to?(y_attr)
      if r.respond_to?(:inside_time_profile) && r.inside_time_profile == false
        _log.debug("Class: [#{r.class}], [#{r.resource_type} - #{r.resource_id}], Timestamp: [#{r.timestamp}] is outside of time profile")
        next
      end
      y = r.send(y_attr).to_f
      # y = r.send(x_attr).to_i # Calculate normal way by using the integer value of the timestamp
      adj_x_attr = "time_profile_adjusted_#{x_attr}"
      if r.respond_to?(adj_x_attr)
        r.send("#{adj_x_attr}=", (recs.first.send(x_attr).to_i + arr.length.days.to_i))
        x = r.send(adj_x_attr).to_i # Calculate by using the number of days out from the first timestamp
      else
        x = r.send(x_attr).to_i
      end
      arr << [x, y]
    end

    begin
      Math.linear_regression(*coordinates)
    rescue StandardError => err
      _log.warn("#{err.message}, calculating slope") unless err.kind_of?(ZeroDivisionError)
      nil
    end
  end

  def self.get_daily_perf(obj, range, ext_options, perf_cols)
    return unless perf_cols

    ext_options ||= {}
    Metric::Helper.find_for_interval_name("daily", ext_options[:time_profile] || ext_options[:tz], ext_options[:class])
                  .order("timestamp") #.select(perf_cols) - Currently passing perf_cols to select is broken because it includes virtual cols. This is actively being worked on.
                  .where(:resource => obj, :timestamp => Metric::Helper.time_range_from_hash(range))
  end

  def self.calc_trend_value_at_timestamp(recs, attr, timestamp)
    slope, yint = calc_slope_from_data(recs, :timestamp, attr)
    return nil if slope.nil?

    begin
      return Math.slope_y_intercept(timestamp.to_f, slope, yint)
    rescue RangeError
      return nil
    rescue => err
      _log.warn("#{err.message}, calculating trend value")
      return nil
    end
  end

  def self.calc_timestamp_at_trend_value(recs, attr, value)
    slope, yint = calc_slope_from_data(recs, :timestamp, attr)
    return nil if slope.nil?

    begin
      return Time.at(Math.slope_x_intercept(value.to_f, slope, yint)).utc
    rescue RangeError
      return nil
    rescue => err
      _log.warn("#{err.message}, calculating timestamp at trend value")
      return nil
    end
  end
end # module VimPerformanceAnalysis
