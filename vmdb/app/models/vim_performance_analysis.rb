module VimPerformanceAnalysis
  class Planning
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
        @compute = @options[:targets][:compute].to_miq_a
        @storage = @options[:targets][:storage].to_miq_a
      elsif @options[:target_tags]
        topts = @options[:target_tags]
        includes = topts[:compute_type].to_sym == :Host ? {:hardware => {}, :vms => {:hardware => {}}} : nil
        if topts[:compute_filter]
          search = topts[:compute_filter].kind_of?(MiqSearch) ? topts[:compute_filter] : MiqSearch.find(topts[:compute_filter])
          @compute, attrs = Rbac.search(:class => topts[:compute_type].to_s ,:filter => search.filter, :results_format => :objects, :include_for_find => includes, :userid => @options[:userid], :miq_group_id => @options[:miq_group_id])
        elsif topts[:compute_tags]
          @compute, attrs = Rbac.search(:class => topts[:compute_type].to_s ,:tag_filters => {"managed" => topts[:compute_tags]}, :results_format => :objects, :include_for_find => includes, :userid => @options[:userid], :miq_group_id => @options[:miq_group_id])
        else
          @compute, attrs = Rbac.search(:class => topts[:compute_type].to_s ,:results_format => :objects, :include_for_find => includes, :userid => @options[:userid], :miq_group_id => @options[:miq_group_id])
        end

        MiqPreloader.preload(@compute, :storages)
        stores = @compute.collect {|c| storages_for_compute_target(c)}.flatten.uniq

        if topts[:storage_filter]
          search = topts[:storage_filter].kind_of?(MiqSearch) ? topts[:storage_filter] : MiqSearch.find(topts[:compute_filter])
          @storage, attrs = Rbac.search(:targets => stores, :class => Storage, :filter => search.filter, :results_format => :objects, :userid => @options[:userid], :miq_group_id => @options[:miq_group_id])
        elsif topts[:storage_tags]
          @storage, attrs = Rbac.search(:targets => stores, :class => Storage, :tag_filters =>  {"managed" => topts[:storage_tags]}, :results_format => :objects, :userid => @options[:userid], :miq_group_id => @options[:miq_group_id])
        else
          @storage, attrs = Rbac.search(:targets => stores, :class => Storage, :results_format => :objects, :userid => @options[:userid], :miq_group_id => @options[:miq_group_id])
        end
      end
      return @compute, @storage
    end

    def storages_for_compute_target(target)
      return target.storages if target.kind_of?(Host)

      if target.kind_of?(EmsCluster)
        return target.hosts.collect(&:storages).flatten.compact
      else
        raise "unable to get storages for #{target.class}"
      end
    end

    # This method answers C&U Planning question 2
    def vm_how_many_more_can_fit(options = {})
      options  ||= @options
      vm_needs   = self.get_vm_needs
      result     = []

      return result, vm_needs if @compute.blank?

      if @compute.first.kind_of?(EmsCluster)
        # For clusters, to allow for fragmentation in calculations, calculate using child hosts and aggregate at the end.
        @hosts_to_cluster = {}

        MiqPreloader.preload(@compute, :hosts => [:hardware, {:vms => :hardware}])
        compute_hosts = @compute.collect do |c|
          c.hosts.each {|h| @hosts_to_cluster[h.id] = c}
          c.hosts
        end.flatten
      else
        MiqPreloader.preload(@compute, [:hardware, {:vms => :hardware}])
        compute_hosts = @compute
      end

      # Set :only_cols for target daily requested cols for better performance
      options[:ext_options][:only_cols] = [:cpu, :memory, :storage].collect {|t| [options[:target_options].fetch_path(t, :metric), options[:target_options].fetch_path(t, :limit_col)]}.flatten.compact
      compute_hosts.each do |c|
        hash = { :target => c }
        count_hash = Hash.new

        need_compute_perf = VimPerformanceAnalysis.needs_perf_data?(options[:target_options])
        start_time, end_time = self.get_time_range(options[:range])
        compute_perf = VimPerformanceAnalysis.get_daily_perf(c, start_time, end_time, options[:ext_options]) if need_compute_perf
        unless need_compute_perf && compute_perf.blank?
          ts = compute_perf.last.timestamp if compute_perf

          [:cpu, :vcpus, :memory].each { |type|
            next if vm_needs[type].nil? || options[:target_options][type].nil?
            if type == :vcpus && vm_needs[type] > c.total_vcpus
              count_hash[type] = { :total => 0 }
              next
            end
            avail, usage = compute_offers(compute_perf, ts, options[:target_options][type], type, c)
            count_hash[type] = { :total => can_fit(avail, usage, vm_needs[type]) }
          }

          unless vm_needs[:storage].nil? || options[:target_options][:storage].nil?
            details = Array.new
            total   = 0
            storages_for_compute_target(c).each { |s|
              avail, usage = storage_offers(compute_perf, ts, options[:target_options][:storage], s)
              fits = can_fit(avail, usage, vm_needs[:storage])
              details << { s.id => fits }
              total += fits unless fits.nil?
            }
            count_hash[:storage] = { :total => total, :details => details }
          end
        end

        total = nil
        count_hash.each_value { |v|
          next if v[:total].nil?
          total = v[:total] if total.nil? || total > v[:total]
        }
        count_hash[:total] = { :total => total }

        hash[:count] = count_hash
        result << hash
      end

      result = how_many_more_can_fit_host_to_cluster_results(result) if @compute.first.kind_of?(EmsCluster)

      # Returns an array of hashes
      # [{:target => Host/Cluster Object, :count => {:total   => {:total => Overall number of instances of provided VM that will fit in the target},
      #                                              :cpu     => {:total => Count based on CPU},
      #                                              :memory  => {:total => Count based on memory},
      #                                              :storage => {:total => Count based on storage, :details => [{<storage.id> => Count for this storage}, ...],
      # ...]
      return result, vm_needs
    end

    def how_many_more_can_fit_host_to_cluster_results(result)
      nh = {}
      result.each do |v|
        cluster = @hosts_to_cluster[v[:target].id]
        nh[cluster.id] ||= {:target => cluster}
        [:cpu, :vcpus, :memory, :storage, :total].each do |type|
          next if v[:count][type].nil?

          nh[cluster.id][:count] ||= {}
          nh[cluster.id][:count][type] ||= {:total => 0}

          chash = nh[cluster.id][:count][type]
          hhash = v[:count][type]

          unless type == :storage
            chash[:total] += hhash[:total] unless hhash[:total].nil?
          else
            # build up array of storage details unique by storage Id
            chash[:details] ||= []
            hhash[:details].each do |h|
              id, val = h.to_a.flatten
              next if chash[:details].find { |i| i.keys.first == id }
              chash[:details] << h
            end
          end
        end
      end

      result = []
      nh.each do |cid,v|
        chash = v[:count][:storage]
        # Calculate storage total based on merged counts.
        chash[:total] = chash[:details].inject(0) {|t,h|
          k,val = h.to_a.flatten
          t += val
        } if v[:count].has_key?(:storage)
        #
        chash = v[:count]
        [:cpu, :vcpus, :memory, :storage].each do |type|
          next unless chash.has_key?(type)
          chash[:total][:total] = chash[type][:total] if chash[type][:total] < chash[:total][:total]
        end
        result << v
      end

      return result
    end

    VM_CONSUMES_METRIC_DEFAULT = {
      :cpu     => {
        :used      => {:metric => :max_cpu_usagemhz_rate_average, :mode => :perf_trend},
        :reserved  => {:metric => :cpu_reserve, :mode => :current},
        :allocated => nil,
        :manual    => {:value =>  nil, :mode => :manual}
      },
      :vcpus  => {
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

      vm_perf = nil
      if VimPerformanceAnalysis.needs_perf_data?(options[:vm_options])
        # Get VM performance data
        start_time, end_time = self.get_time_range(options[:range])
        # Set :only_cols for VM daily requested cols for better performance
        options[:ext_options] ||= {}
        options[:ext_options][:only_cols] = [:cpu, :vcpus, :memory, :storage].collect {|t| options[:vm_options][t][:metric] if options[:vm_options][t]}.compact
        vm_perf    = VimPerformanceAnalysis.get_daily_perf(@vm, start_time, end_time, options[:ext_options])
      end

      @vm_needs = Hash.new
      vm_ts = vm_perf.last.timestamp unless vm_perf.blank?
      [:cpu, :vcpus, :memory, :storage].each { |type|
        @vm_needs[type] = vm_consumes(vm_perf, vm_ts, options[:vm_options][type], type)
      }
      return @vm_needs
    end

    def vm_consumes(perf, ts, options, type, vm = @vm)
      return nil if options.nil?

      options[:metric] ||= VM_CONSUMES_METRIC_DEFAULT[type][:used][:metric]
      options[:mode]   ||= VM_CONSUMES_METRIC_DEFAULT[type][:used][:metric]

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
      :cpu     => :total_vm_cpu_reserve,
      :memory  => :total_vm_memory_reserve,
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

      options[:mode]      ||= COMPUTE_OFFERS_MODE_DEFAULT[type]
      options[:metric]    ||= COMPUTE_OFFERS_METRIC_DEFAULT[type]
      options[:reserve]   ||= COMPUTE_OFFERS_RESERVE_METRIC_DEFAULT[type]
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
        avail   = (options[:limit_ratio] - target.vcpus_per_core) * target.total_cores
      else
        usage   = measure_object(target, options[:mode], options[:metric],    perf, ts, type) || 0
        reserve = measure_object(target, :current,       options[:reserve],   perf, ts, type) || 0
        avail   = measure_object(target, options[:mode], options[:limit_col], perf, ts, type) || 0
        avail   = (avail * (options[:limit_pct] / 100.0)) unless avail.nil? || options[:limit_pct].blank?
      end
      usage = (usage > reserve) ? usage : reserve # Take the greater of usage or total reserve of child VMs
      return [avail, usage]
    end

    def compute_offers(perf, ts, options, type, target)
      offers(perf, ts, options, type, target)
    end

    def storage_offers(perf, ts, options, storage)
      offers(perf, ts, options, :storage, storage)
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
        raise "Unsupported Mode (#{mode}) for #{obj.class} #{type} options"
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
      return {:recomendations => [hash], :errors => nil}
    end

    def get_time_range(range)
      ##########################################################
      #   :range        => Trend calculation options
      #     :days         => Number of days back from daily_date
      #     :end_date     => Ending date
      ##########################################################
      range[:days]     ||= 20
      range[:end_date] ||= Time.now

      start_time = (range[:end_date].utc - range[:days].days)
      end_time   = Time.now.utc

      return start_time, end_time
    end
  end # class Planning

  # Helper methods

  def self.needs_perf_data?(options)
    options.each {|k,v| return true if v && v[:mode] == :perf_trend}
    return false
  end

  def self.find_perf_for_time_period(obj, interval_name, options = {})
    # Options
    #   :days        => Number of days back from end_date. Used only if start_date not passed
    #   :start_date  => Starting date
    #   :end_date    => Ending date
    #   :conditions  => ActiveRecord find conditions

    options[:end_date] ||= Time.now.utc
    start_time = (options[:start_date] || (options[:end_date].utc - options[:days].days)).utc
    end_time   = options[:end_date].utc

    user_cond = nil
    user_cond = obj.class.send(:sanitize_sql_for_conditions, options[:conditions]) if options[:conditions]
    cond =  obj.class.send(:sanitize_sql_for_conditions, ["(timestamp > ? and timestamp <= ?)", start_time.utc, end_time.utc])
    cond += obj.class.send(:sanitize_sql_for_conditions, [" AND resource_type = ? AND resource_id = ?", obj.class.base_class.name, obj.id])
    cond += "AND capture_interval_name = #{interval_name}" unless interval_name == "daily"
    cond =  "(#{user_cond}) AND (#{cond})" if user_cond

    # puts "find_perf_for_time_period: cond: #{cond.inspect}"

    if interval_name == "daily"
      VimPerformanceDaily.all(:conditions => cond, :order => "timestamp", :ext_options => options[:ext_options], :select => options[:select])
    else
      klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)
      klass.where(cond).order("timestamp").select(options[:select]).to_a
    end
  end

  def self.find_child_perf_for_time_period(obj, interval_name, options = {})
    # Options
    #   :days        => Number of days back from end_date. Used only if start_date not passed
    #   :start_date  => Starting date
    #   :end_date    => Ending date
    #   :conditions  => ActiveRecord find conditions

    start_time = (options[:start_date] || (options[:end_date].utc - options[:days].days)).utc
    end_time   = options[:end_date].utc
    klass, _   = Metric::Helper.class_and_association_for_interval_name(interval_name)

    user_cond = nil
    user_cond = klass.send(:sanitize_sql_for_conditions, options[:conditions]) if options[:conditions]
    cond =  klass.send(:sanitize_sql_for_conditions, ["(timestamp > ? AND timestamp <= ?)", start_time.utc, end_time.utc])
    cond += klass.send(:sanitize_sql_for_conditions, [" AND capture_interval_name = ?", interval_name]) unless interval_name == "daily"
    cond =  "(#{user_cond}) AND (#{cond})" if user_cond

    if obj.kind_of?(MiqEnterprise) || obj.kind_of?(MiqRegion)
      cond1 = klass.send(:sanitize_sql_for_conditions, {:resource_type => "Storage",             :resource_id => obj.storage_ids})
      cond2 = klass.send(:sanitize_sql_for_conditions, {:resource_type => "ExtManagementSystem", :resource_id => obj.ext_management_system_ids})
      cond += " AND ((#{cond1}) OR (#{cond2}))"
    else
      parent_col = case obj
      when Host;                :parent_host_id
      when EmsCluster;          :parent_ems_cluster_id
      when Storage;             :parent_storage_id
      when ExtManagementSystem; :parent_ems_id
      else                      raise "unknown object type: #{obj.class}"
      end

      cond += " AND #{parent_col} = ?"
      cond += " AND resource_type in ('Host', 'EmsCluster')" if obj.kind_of?(ExtManagementSystem)
      cond = [cond, obj.id]
    end

    # puts "find_child_perf_for_time_period: cond: #{cond.inspect}"

    if interval_name == "daily"
      VimPerformanceDaily.all(:conditions => cond, :ext_options => options[:ext_options], :select => options[:select])
    else
      klass.where(cond).select(options[:select]).to_a
    end
  end

  def self.child_tags_over_time_period(obj, interval_name, options = {})
    # Options
    #   :days        => Number of days back from daily_date
    #   :end_date    => Ending date

    # Returns a hash:
    #   "Host/environment/prod" => "Host: Environment: Production",
    #   "Host/environment/dev"  => "Host: Environment: Development"
    classifications = Classification.hash_all_by_type_and_name

    self.find_child_perf_for_time_period(obj, interval_name, options.merge(:conditions => "resource_type != 'VmOrTemplate' AND tag_names IS NOT NULL", :select => "resource_type, tag_names")).inject({}) do |h,p|
      p.tag_names.split("|").each do |t|
        next if t.starts_with?("power_state")
        tag = "#{p.resource_type}/#{t}"
        next if h.has_key?(tag)

        c, e = t.split("/")
        cat = classifications.fetch_path(c, :category)
        cat_desc = cat.nil? ? c.titleize : cat.description
        ent = cat.nil? ? nil : classifications.fetch_path(c, :entry, e)
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

        Metric::Aggregation.aggregate_for_column(c, nil, result[key], counts[key], p.send(c), :average)
      end
    end

    result.each do |k,h|
      h[:min_max] = h.keys.find_all {|k| k.to_s.starts_with?("min") || k.to_s.starts_with?("max")}.inject({}) do |mm,k|
        val = h.delete(k)
        mm[k] = val unless val.nil?
        mm
      end
    end

    result.inject([]) do |recs, k|
      ts, v = k
      cols.each do |c|
        next unless v[c].kind_of?(Float)
        Metric::Aggregation.process_for_column(c, nil, v, counts[k], true, :average)
      end

      recs.push(perf_klass.new(v))
      recs
    end
  end

  def self.calc_slope_from_data(recs, x_attr, y_attr)
    recs.sort!{|a,b| a.send(x_attr) <=> b.send(x_attr)} if recs.first.respond_to?(x_attr)

    y_array, x_array = recs.inject([]) do |arr,r|
      arr[0] ||= []; arr[1] ||= []
      next(arr) unless  r.respond_to?(x_attr) && r.respond_to?(y_attr)
      if r.respond_to?(:inside_time_profile) && r.inside_time_profile == false
        $log.debug("MIQ(VimPerformanceAnalysis.calc_slope_from_data) Class: [#{r.class}], [#{r.resource_type} - #{r.resource_id}], Timestamp: [#{r.timestamp}] is outside of time profile")
        next(arr)
      end
      arr[0] << r.send(y_attr).to_f
      # arr[1] << r.send(x_attr).to_i # Calculate normal way by using the integer value of the timestamp
      adj_x_attr = "time_profile_adjusted_#{x_attr}"
      if r.respond_to?(adj_x_attr)
        r.send("#{adj_x_attr}=", (recs.first.send(x_attr).to_i + arr[1].length.days.to_i))
        arr[1] << r.send(adj_x_attr).to_i # Caculate by using the number of days out from the first timestamp
      else
        arr[1] << r.send(x_attr).to_i
      end
      arr
    end

    begin
      slope_arr = MiqStats.slope(x_array.to_miq_a, y_array.to_miq_a)
    rescue ZeroDivisionError
      slope_arr = []
    rescue => err
      $log.warn("MIQ(VimPerformanceAnalysis.calc_slope_from_data) #{err.message}, calculating slope")
      slope_arr = []
    end
    return slope_arr
  end

  def self.get_daily_perf(obj, start_time, end_time, options)
    cond = ["resource_type = ? and resource_id = ? and (timestamp > ? and timestamp <= ?)", obj.class.base_class.name, obj.id, start_time.utc, end_time.utc]
    results = VimPerformanceDaily.find(:all, :conditions => cond, :order => "timestamp", :ext_options => options)

    # apply time profile to returned records if one was specified
    results.each {|rec| rec.apply_time_profile(options[:time_profile]) if rec.respond_to?(:apply_time_profile)} unless options[:time_profile].nil?
    return results
  end

  def self.calc_trend_value_at_timestamp(recs, attr, timestamp)
    slope, yint = self.calc_slope_from_data(recs, :timestamp, attr)
    return nil if slope.nil?

    begin
      return MiqStats.solve_for_y(timestamp.to_f, slope, yint)
    rescue RangeError
      return nil
    rescue => err
      $log.warn("MIQ(VimPerformanceAnalysis-calc_trend_value_at_timestamp) #{err.message}, calculating trend value")
      return nil
    end
  end

  def self.calc_timestamp_at_trend_value(recs, attr, value)
    slope, yint = self.calc_slope_from_data(recs, :timestamp, attr)
    return nil if slope.nil?

    begin
      return Time.at(MiqStats.solve_for_x(value.to_f, slope, yint)).utc
    rescue RangeError
      return nil
    rescue => err
      $log.warn("MIQ(VimPerformanceAnalysis-calc_timestamp_at_trend_value) #{err.message}, calculating timestamp at trend value")
      return nil
    end
  end
end # module VimPerformanceAnalysis
