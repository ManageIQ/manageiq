module Metric::Processing
  DERIVED_COLS = {
    :derived_cpu_available             => :generate_derived_cpu_available,
    :derived_cpu_reserved              => :generate_derived_cpu_reserved,
    :derived_host_count_off            => :generate_derived_host_count_off,
    :derived_host_count_on             => :generate_derived_host_count_on,
    :derived_host_count_total          => :generate_derived_host_count_total,
    :derived_memory_available          => :generate_derived_memory_available,
    :derived_memory_reserved           => :generate_derived_memory_reserved,
    :derived_memory_used               => :generate_derived_memory_used,
    :derived_host_sockets              => :generate_derived_host_sockets,
    :derived_vm_allocated_disk_storage => :generate_derived_vm_allocated_disk_storage,
    :derived_vm_count_off              => :generate_derived_vm_count_off,
    :derived_vm_count_on               => :generate_derived_vm_count_on,
    :derived_vm_count_total            => :generate_derived_vm_count_total,
    # TODO: This is cpu_total_cores and needs to be renamed, but reports depend on the name :numvcpus
    :derived_vm_numvcpus               => :generate_derived_vm_numvcpus,
    # See also #TODO on VimPerformanceState.capture
    :derived_vm_used_disk_storage      => :generate_derived_vm_used_disk_storage,
    # TODO(lsmola) as described below, this field should be named derived_cpu_used
    :cpu_usagemhz_rate_average         => :generate_cpu_usagemhz_rate_average
  }.freeze

  VALID_PROCESS_TARGETS = [
    VmOrTemplate,
    Container,
    ContainerGroup,
    ContainerNode,
    ContainerProject,
    ContainerReplicator,
    ContainerService,
    Host,
    AvailabilityZone,
    HostAggregate,
    EmsCluster,
    ExtManagementSystem,
    MiqRegion,
    MiqEnterprise,
    Service
  ]

  def self.process_derived_columns(obj, attrs, ts = nil)
    unless VALID_PROCESS_TARGETS.any? { |t| obj.kind_of?(t) }
      raise _("object %{name} is not one of %{items}") % {:name  => obj,
                                                          :items => VALID_PROCESS_TARGETS.collect(&:name).join(", ")}
    end

    ts = attrs[:timestamp] if ts.nil?
    state = obj.vim_performance_state_for_ts(ts)
    result = {}

    DERIVED_COLS.each { |col, method| send(method, col, state, attrs, result) }

    result[:assoc_ids] = state.assoc_ids
    result[:tag_names] = state.tag_names
    result[:parent_host_id] = state.parent_host_id
    result[:parent_storage_id] = state.parent_storage_id
    result[:parent_ems_id] = state.parent_ems_id
    result[:parent_ems_cluster_id] = state.parent_ems_cluster_id
    result
  end

  def self.add_missing_intervals(obj, interval_name, start_time, end_time)
    klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)

    scope = obj.send(meth).for_time_range(start_time, end_time)
    scope = scope.where(:capture_interval_name => interval_name) if interval_name != "realtime"
    extrapolate(klass, scope)
  end

  def self.extrapolate(klass, scope)
    last_perf = {}
    scope.order("timestamp, capture_interval_name").each do |perf|
      interval = interval_name_to_interval(perf.capture_interval_name)
      last_perf[interval] = perf if last_perf[interval].nil?

      if (perf.timestamp - last_perf[interval].timestamp) <= interval
        last_perf[interval] = perf
        next
      end

      new_perf = create_new_metric(klass, last_perf[interval], perf, interval)
      new_perf.save!

      last_perf[interval] = perf
    end
  end

  def self.create_new_metric(klass, last_perf, perf, interval)
    attrs = last_perf.attributes
    attrs.delete('id')
    attrs['timestamp'] += interval
    attrs['capture_interval'] = 0
    new_perf = klass.new(attrs)
    Metric::Rollup::ROLLUP_COLS.each do |c|
      next if new_perf.send(c).nil? || perf.send(c).nil?
      new_perf.send(c.to_s + "=", (new_perf.send(c) + perf.send(c)) / 2)
    end

    unless perf.assoc_ids.nil?
      Metric::Rollup::ASSOC_KEYS.each do |assoc|
        next if new_perf.assoc_ids.nil? || new_perf.assoc_ids[assoc].blank? || perf.assoc_ids[assoc].blank?
        new_perf.assoc_ids[assoc][:on] ||= []
        new_perf.assoc_ids[assoc][:off] ||= []
        new_perf.assoc_ids[assoc][:on]  = (new_perf.assoc_ids[assoc][:on] + perf.assoc_ids[assoc][:on]).uniq!
        new_perf.assoc_ids[assoc][:off] = (new_perf.assoc_ids[assoc][:off] + perf.assoc_ids[assoc][:off]).uniq!
      end
    end
    new_perf
  end
  private_class_method :extrapolate, :create_new_metric

  def self.interval_name_to_interval(name)
    case name
    when "realtime" then 20
    when "hourly" then   1.hour.to_i
    when "daily" then    1.day.to_i
    else raise _("unknown interval name: [%{name}]") % {:name => name}
    end
  end

  ##### DEFINING METHODS FOR .process_derived_columns #####

  # Shared_methods
  def self.cpu_metrics?(attrs)
    attrs[:cpu_usage_rate_average] || attrs[:cpu_usagemhz_rate_average]
  end
  private_class_method :cpu_metrics?

  def self.mem_metrics?(attrs)
    attrs[:mem_usage_absolute_average] || attrs[:derived_memory_used]
  end
  private_class_method :mem_metrics?

  # Defines:
  #   total_cpu                         (helper method)
  #   total_mem                         (helper method)
  #   generate_derived_cpu_available
  #   generate_derived_cpu_reserved     (calls state.reserve_cpu)
  #   generate_derived_memory_available
  #   generate_derived_memory_reserved  (calls state.reserve_mem)
  %w[cpu memory].each do |group|
    method_def = <<-METHOD_DEF
      def self.total_#{group[0..2]}(state)
        state.total_#{group[0..2]} || 0
      end
      private_class_method :total_#{group[0..2]}

      def self.generate_derived_#{group}_available(col, state, attrs, result)
        result[col] = total_#{group[0..2]}(state) if #{group[0..2]}_metrics?(attrs) && total_#{group[0..2]}(state) > 0
      end
      private_class_method :generate_derived_#{group}_available

      def self.generate_derived_#{group}_reserved(col, state, _, result)
        result[col] = state.reserve_#{group[0..2]}
      end
      private_class_method :generate_derived_#{group}_reserved
    METHOD_DEF
    eval method_def.split("\n").map(&:strip).join(';')
  end

  # Defines:
  #   generate_derived_host_count_off
  #   generate_derived_host_count_on
  #   generate_derived_host_count_total
  #   generate_derived_vm_count_off
  #   generate_derived_vm_count_on
  #   generate_derived_vm_count_total
  %w[host vm].each do |group|
    %w[off on total].each do |mode|
      method_def = <<-METHOD_DEF
        def self.generate_derived_#{group}_count_#{mode}(col, state, _, result)
          result[col] = state.#{group}_count_#{mode}
        end
        private_class_method :generate_derived_#{group}_count_#{mode}
      METHOD_DEF
      eval method_def.split("\n").map(&:strip).join(';')
    end
  end

  # Defines:
  #   generate_host_count_off
  #   generate_host_count_on
  #   generate_host_count_total
  %i[host_sockets vm_allocated_disk_storage vm_used_disk_storage].each do |method|
    method_def = <<-METHOD_DEF
      def self.generate_derived_#{method}(col, state, _, result)
        result[col] = state.#{method} if state.respond_to?(:#{method})
      end
      private_class_method :generate_derived_#{method}
    METHOD_DEF
    eval method_def.split("\n").map(&:strip).join(';')
  end

  def self.generate_derived_memory_used(col, state, attrs, result)
    if total_mem(state) > 0 # eject early since we can't do anything without this having a value
      if attrs[:mem_usage_absolute_average].nil? && !attrs[:derived_memory_used].nil?
        # If we can't get percentage usage, just used RAM in MB, lets compute percentage usage
        # FIXME: Is this line a bug?  Why are we assigning attr here?
        attrs[:mem_usage_absolute_average] = 100.0 / total_mem(state) * attrs[:derived_memory_used]
      elsif !attrs[:mem_usage_absolute_average].nil?
        # We have percentage usage of RAM, lets compute consumed RAM in MB
        result[col] = (attrs[:mem_usage_absolute_average] / 100 * total_mem(state))
      end
    end
  end
  private_class_method :generate_derived_memory_used

  # This is actually logical cpus.  See note above for :derived_vm_numvcpus
  def self.generate_derived_vm_numvcpus(col, state, attrs, result)
    # Do not derive "available" values if there haven't been any usage values collected
    result[col] = state.numvcpus if cpu_metrics?(attrs) && state.try(:numvcpus).to_i > 0
  end
  private_class_method :generate_derived_vm_numvcpus

  def self.generate_cpu_usagemhz_rate_average(col, state, attrs, result)
    if attrs[:cpu_usagemhz_rate_average].blank? && total_cpu(state) > 0 && !attrs[:cpu_usage_rate_average].nil?
      # TODO(lsmola) for some reason, this column is used in chart, although from processing code above, it should
      # be named derived_cpu_used. Investigate what is the right solution and make it right. For now lets fill
      # the column shown in charts.
      result[col] = (attrs[:cpu_usage_rate_average] / 100 * total_cpu(state))
    end
  end
  private_class_method :generate_cpu_usagemhz_rate_average
end
