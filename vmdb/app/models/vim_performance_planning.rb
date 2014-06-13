class VimPerformancePlanning < ActsAsArModel
  set_columns_hash(
    :name             => :string,
    :id               => :integer,
    :resource_type    => :string,
    :total_vm_count   => :integer,
    :cpu_vm_count     => :integer,
    :vcpus_vm_count   => :integer,
    :memory_vm_count  => :integer,
    :storage_vm_count => :integer
  )

  def self.build_results_for_report_planning(options)
    # Options
    #   :targets      => Defines explicit target Cluster or Host and Datastore - mutually exclusive with :tags
    #     :cluster      => Target cluster(s)
    #     :host         => Target host(s)
    #     :storage      => Target storage(s)
    #   :target_tags  => Defines tags that will be used to select targets - mutually exclusive with :targets
    #     :compute_filter => MiqSearch instance of id
    #     :compute_type   => :EmsCluster || :Host - Select host or cluster as target
    #     :compute_tags   => Array of arrays of management tags used for selecting targets. inner array elements are 'And'ed, outter arrays are 'OR'ed
    #                        Example: [["/managed/department/accounting", "/managed/department/automotive"], ["/managed/environment/prod"], ["/managed/function/desktop"]]
    #     :storage_filter => MiqSearch instance of id
    #     :storage_tags   => Same as above for storage selection only

    vm = VmOrTemplate.extract_objects(options.delete(:vm))

    targets = options[:targets]
    if targets
      if options[:targets][:cluster]
        targets[:compute] = EmsCluster.extract_objects(targets.delete(:cluster))
      elsif options[:targets][:host]
        targets[:compute] = Host.extract_objects(targets.delete(:host))
      else
        raise "Targets must contain a cluster or a host key"
      end

      targets[:storage] = Storage.extract_objects(targets[:storage])
    end

    anal = VimPerformanceAnalysis::Planning.new(vm, targets ? options.merge(:targets => targets) : options)
    recs, vm_profile = anal.vm_how_many_more_can_fit(options)

    # [{:target => Host/Cluster Object, :count => {:total   => {:total => Overall number of instances of provided VM that will fit in the target},
    #                                              :cpu     => {:total => Count based on CPU},
    #                                              :memory  => {:total => Count based on memory},
    #                                              :storage => {:total => Count based on storage, :details => [{<storage.id> => Count for this storage}, ...],
    # ...]
    results = recs.inject([]) do |a, r|
      rec = self.new(
        :name             => r[:target].name,
        :id               => r[:target].id,
        :resource_type    => r[:target].class.name,
        :total_vm_count   => r[:count][:total][:total]
      )
      rec[:cpu_vm_count]     = r[:count][:cpu][:total]      if r[:count].has_key?(:cpu)
      rec[:vcpus_vm_count]   = r[:count][:vcpus][:total]    if r[:count].has_key?(:vcpus)
      rec[:memory_vm_count]  = r[:count][:memory][:total]   if r[:count].has_key?(:memory)
      rec[:storage_vm_count] = r[:count][:storage][:total]  if r[:count].has_key?(:storage)
      a << rec
    end

    # format VM profile values
    [:cpu, :vcpus, :memory, :storage].each do |t|
      next if vm_profile.nil? || vm_profile[t].nil?
      if vm_profile[t] < 0
        vm_profile[t] = nil
        next
      end

      method = case t
        when :cpu     then vm_profile[t] = "#{vm_profile[t].round} MHz"
        when :memory  then vm_profile[t] = "#{vm_profile[t].round} MB"
        when :storage then vm_profile[t] = "#{(vm_profile[t].to_i / 1.gigabyte).round} GB"
      end
    end
    return results, {:vm_profile => vm_profile}
  end

  def self.vm_default_options(based_on)
    # based_on => (:allocated, :reserved, :used)
    #
    # Returns = {
    #   :cpu    => {
    #     :mode   => :perf_trend,
    #     :metric => :max_cpu_usagemhz_rate_average
    #   },
    #   :vcpus  => {
    #     :mode   => :current,
    #     :metric => :num_cpu
    #   },
    #   :memory => {
    #     :mode   => :perf_trend,
    #     :metric => :max_derived_memory_used
    #   },
    #   :storage => {
    #     :mode   => :current,
    #     :metric => :used_disk_storage
    #   }
    # }

    VimPerformanceAnalysis::Planning::VM_CONSUMES_METRIC_DEFAULT.inject({}) do |h,v|
      key, value = v
      h[key] = value[based_on].dup unless value[based_on].nil?
      h
    end
  end

  def self.vm_metric_values(vm, options)
    # options => {
    #     :vm_options => {},
    #     :range => {:days => 20, :end_date => "xxxxx"},
    #     :tz => "string of time zone",
    #     :time_profile_id => <ID of time profile>
    # }

    options[:ext_options] = {:tz => options[:tz], :time_profile => TimeProfile.find_by_id(options[:time_profile_id])}

    anal = VimPerformanceAnalysis::Planning.new(vm, options)
    vm_needs =anal.get_vm_needs

    # add value key to each of the passed in options
    vm_needs.each do |k,v|
      options[:vm_options][k][:value] = v.round unless options[:vm_options][k].nil? || v.nil?
    end
    return options
  end
end #class VimPerformancePlanning
