module EmsCluster::CapacityPlanning
  extend ActiveSupport::Concern

  CAPACITY_PROFILES   = [1, 2]
  CAPACITY_RESOURCES  = [:vcpu, :memory]
  CAPACITY_ALGORITHMS = [:average, :high_norm]

  CAPACITY_PLANNING_VCOLS =
    CAPACITY_PROFILES.each_with_object({}) do |profile, h|
      prefix = "capacity_profile_#{profile}"
      CAPACITY_RESOURCES.each do |resource|
        h[:"#{prefix}_#{resource}_method"]              = :string
        h[:"#{prefix}_#{resource}_commitment_ratio"]    = :float
        h[:"#{prefix}_#{resource}_minimum"]             = :float
        h[:"#{prefix}_#{resource}_maximum"]             = :float

        h[:"#{prefix}_available_host_#{resource}"]      = :float
        h[:"#{prefix}_remaining_host_#{resource}"]      = :float
        h[:"#{prefix}_#{resource}_per_vm"]              = :float
        h[:"#{prefix}_#{resource}_per_vm_with_min_max"] = :float

        h[:"#{prefix}_remaining_vm_count_based_on_#{resource}"] = :integer
        h[:"#{prefix}_projected_vm_count_based_on_#{resource}"] = :integer
      end
      h[:"#{prefix}_remaining_vm_count_based_on_all"] = :integer
      h[:"#{prefix}_projected_vm_count_based_on_all"] = :integer
    end

  included do
    class_eval do
      CAPACITY_PLANNING_VCOLS.each do |vcol, type|
        virtual_column vcol, :type => type
      end
    end
  end

  module ClassMethods
    def capacity_settings
      VMDB::Config.new('capacity').config
    end
  end

  #
  # Settings methods
  #

  def capacity_settings
    @capacity_settings ||= self.class.capacity_settings
  end

  def capacity_profile_settings(profile)
    capacity_settings.fetch_path(:profile, profile.to_s.to_sym) || {}
  end

  def capacity_profile_method(profile, resource)
    @capacity_profile_method ||= {}
    value = @capacity_profile_method.fetch_path(profile, resource)
    return value unless value.nil?

    algorithm = capacity_profile_settings(profile)[:"#{resource}_method"].to_s
    algorithm_resource, _, algorithm_method = algorithm.partition("_")
    algorithm_resource = "vcpu"   if algorithm_resource == "cpu"
    algorithm_resource = "memory" if algorithm_resource == "mem"
    raise "Invalid #{resource}_method specified: #{algorithm.inspect}" if algorithm_resource.blank? || algorithm_method.blank? || algorithm_resource.to_sym != resource || !CAPACITY_ALGORITHMS.include?(algorithm_method.to_sym)

    @capacity_profile_method.store_path(profile, resource, :"#{algorithm_resource}_#{algorithm_method}")
  end

  def capacity_profile_method_description(profile, resource)
    capacity_profile_settings(profile)[:"#{resource}_method_description"]
  end

  def capacity_profile_minimum(profile, resource)
    min = capacity_profile_settings(profile)[:"#{resource}_minimum"]
    min && min.to_i_with_method
  end

  def capacity_profile_maximum(profile, resource)
    max = capacity_profile_settings(profile)[:"#{resource}_maximum"]
    max && max.to_i_with_method
  end

  def capacity_commitment_ratio(profile, resource)
    (capacity_profile_settings(profile)[:"#{resource}_commitment_ratio"] || 1.0).to_f
  end

  def capacity_failover_rule
    @capacity_failover_rule ||= begin
      failover_rule = capacity_settings.fetch_path(:failover, :rule).to_s.downcase.strip
      failover_rule = 'discovered' unless ['none', 'discovered'].include?(failover_rule)
      failover_rule
    end
  end

  #
  # Helper methods
  #

  def capacity_average_resources_per_vm(resource_value)
    total = self.total_vms
    return 0.0 if total == 0
    resource_value / total.to_f
  end

  def capacity_average_resources_per_host(resource_value)
    total = self.total_hosts
    return 0.0 if total == 0
    resource_value / total.to_f
  end

  def capacity_peak_usage_percentage(resource)
    case resource
    when :vcpu;   self.max_cpu_usage_rate_average_high_over_time_period_without_overhead     || 100.0
    when :memory; self.max_mem_usage_absolute_average_high_over_time_period_without_overhead || 100.0
    end
  end

  #
  # Formula Methods
  #

  def capacity_effective_host_resources(profile, resource)
    case capacity_profile_method(profile, resource)
    when :vcpu_average;                      self.aggregate_logical_cpus
    when :memory_average, :memory_high_norm; self.effective_memory || self.aggregate_memory.megabytes
    when :vcpu_high_norm;                    self.effective_cpu    || self.aggregate_cpu_speed
    end
  end

  def capacity_failover_host_resources(profile, resource)
    return 0 if capacity_failover_rule == 'none' || (capacity_failover_rule == 'discovered' && !self.ha_enabled?)

    if self.failover_hosts.length > 0
      capacity_failover_host_resources_with_failover_hosts(profile, resource)
    else
      # TODO: Support the other ways to specify failover
      #   (i.e. number of hosts and percentage of resources)
      capacity_failover_host_resources_without_failover_hosts(profile, resource)
    end
  end

  def capacity_failover_host_resources_with_failover_hosts(profile, resource)
    case capacity_profile_method(profile, resource)
    when :vcpu_average;                      self.aggregate_logical_cpus(self.failover_hosts)
    when :memory_average, :memory_high_norm; self.aggregate_memory(self.failover_hosts).megabytes
    when :vcpu_high_norm;                    self.aggregate_cpu_speed(self.failover_hosts)
    end
  end

  def capacity_failover_host_resources_without_failover_hosts(profile, resource)
    # Take the average resources per 1 Host
    resource_value = case capacity_profile_method(profile, resource)
    when :vcpu_average;                      self.aggregate_logical_cpus
    when :memory_average, :memory_high_norm; self.aggregate_memory.megabytes
    when :vcpu_high_norm;                    self.aggregate_cpu_speed
    end
    capacity_average_resources_per_host(resource_value)
  end

  def capacity_used_host_resources(profile, resource)
    case capacity_profile_method(profile, resource)
    when :vcpu_average;     self.aggregate_vm_cpus
    when :memory_average;   self.aggregate_vm_memory.megabytes
    when :vcpu_high_norm;   capacity_available_host_resources(profile, resource) * (capacity_peak_usage_percentage(:vcpu)   / 100.0)
    when :memory_high_norm; capacity_available_host_resources(profile, resource) * (capacity_peak_usage_percentage(:memory) / 100.0)
    end
  end

  def capacity_resources_per_vm(profile, resource)
    resource_value = capacity_used_host_resources(profile, resource)
    capacity_average_resources_per_vm(resource_value)
  end

  def capacity_resources_per_vm_with_min_max(profile, resource)
    min = capacity_profile_minimum(profile, resource)
    max = capacity_profile_maximum(profile, resource)
    capacity_resources_per_vm(profile, resource).apply_min_max(min, max)
  end

  def capacity_available_host_resources(profile, resource)
    [capacity_effective_host_resources(profile, resource) - capacity_failover_host_resources(profile, resource), 0.0].max
  end

  def capacity_committed_host_resources(profile, resource)
    capacity_commitment_ratio(profile, resource) * capacity_available_host_resources(profile, resource)
  end

  def capacity_remaining_host_resources(profile, resource)
    capacity_committed_host_resources(profile, resource) - capacity_used_host_resources(profile, resource)
  end

  def capacity_remaining_vm_count(profile, resource)
    resources_per_vm = capacity_resources_per_vm_with_min_max(profile, resource)
    return 0 if resources_per_vm == 0.0
    (capacity_remaining_host_resources(profile, resource) / resources_per_vm).to_i
  end

  #
  # Profile methods
  #

  def capacity_remaining_vm_count_based_on_all(profile)
    CAPACITY_RESOURCES.collect { |resource| capacity_remaining_vm_count(profile, resource) }.min
  end

  def capacity_projected_vm_count(profile, resource)
    self.total_vms + capacity_remaining_vm_count(profile, resource)
  end

  def capacity_projected_vm_count_based_on_all(profile)
    CAPACITY_RESOURCES.collect { |resource| capacity_projected_vm_count(profile, resource) }.min
  end

  CAPACITY_PROFILES.each do |profile|
    prefix = "capacity_profile_#{profile}"

    CAPACITY_RESOURCES.each do |resource|
      define_method("#{prefix}_#{resource}_method") do
        capacity_profile_method_description(profile, resource)
      end

      define_method("#{prefix}_#{resource}_commitment_ratio") do
        capacity_commitment_ratio(profile, resource)
      end

      define_method("#{prefix}_#{resource}_minimum") do
        capacity_profile_minimum(profile, resource)
      end

      define_method("#{prefix}_#{resource}_maximum") do
        capacity_profile_minimum(profile, resource)
      end

      define_method("#{prefix}_available_host_#{resource}") do
        capacity_available_host_resources(profile, resource)
      end

      define_method("#{prefix}_remaining_host_#{resource}") do
        capacity_remaining_host_resources(profile, resource)
      end

      define_method("#{prefix}_#{resource}_per_vm") do
        capacity_resources_per_vm(profile, resource)
      end

      define_method("#{prefix}_#{resource}_per_vm_with_min_max") do
        capacity_resources_per_vm_with_min_max(profile, resource)
      end

      define_method("#{prefix}_remaining_vm_count_based_on_#{resource}") do
        capacity_remaining_vm_count(profile, resource)
      end

      define_method("#{prefix}_projected_vm_count_based_on_#{resource}") do
        capacity_projected_vm_count(profile, resource)
      end
    end

    define_method("#{prefix}_remaining_vm_count_based_on_all") do
      capacity_remaining_vm_count_based_on_all(profile)
    end

    define_method("#{prefix}_projected_vm_count_based_on_all") do
      capacity_projected_vm_count_based_on_all(profile)
    end
  end
end
