class VimPerformanceState < ActiveRecord::Base
  serialize :state_data

  belongs_to :resource, :polymorphic => true

  ASSOCIATIONS = [:vms, :hosts, :ems_clusters, :ext_management_systems, :storages]

  # Define accessors for state_data information
  [
    :assoc_ids,
    :parent_host_id,
    :parent_storage_id,
    :parent_ems_id,
    :parent_ems_cluster_id,
    :tag_names,
    :numvcpus,
    :total_cpu,
    :total_mem,
    :reserve_cpu,
    :reserve_mem,
    :vm_allocated_disk_storage,
    :vm_used_disk_storage
  ].each do |m|
    define_method(m)       { state_data[m] }
    define_method("#{m}=") { |value| state_data[m] = value }
  end

  # state_data:
  # => assoc_ids
  # => total_memory
  # => total_cpu
  # => reserve_memory
  # => reserve_cpu
  # => vm_count_on      (derive from assoc_ids)
  # => vm_count_off     (derive from assoc_ids)
  # => host_count_on    (derive from assoc_ids)
  # => host_count_off   (derive from assoc_ids)

  def self.capture(obj)
    ts = Time.now.utc
    ts = Time.utc(ts.year, ts.month, ts.day, ts.hour)
    state = obj.vim_performance_states.find_by_timestamp(ts)
    return state unless state.nil?

    state = obj.vim_performance_states.build
    state.state_data ||= Hash.new
    state.timestamp = ts
    state.capture_interval = 3600
    state.assoc_ids = self.capture_assoc_ids(obj)
    state.parent_host_id = self.capture_parent_host(obj)
    state.parent_storage_id = self.capture_parent_storage(obj)
    state.parent_ems_id = self.capture_parent_ems(obj)
    state.parent_ems_cluster_id = self.capture_parent_cluster(obj)
    state.numvcpus = self.capture_numvcpus(obj)
    state.total_cpu = self.capture_total(obj, :cpu_speed)
    state.total_mem = self.capture_total(obj, :memory)
    state.reserve_cpu = self.capture_reserve(obj, :cpu_reserve)
    state.reserve_mem = self.capture_reserve(obj, :memory_reserve)
    state.vm_used_disk_storage = self.capture_vm_disk_storage(obj, :used_disk)
    state.vm_allocated_disk_storage = self.capture_vm_disk_storage(obj, :allocated_disk)
    state.tag_names = self.capture_tag_names(obj)
    state.save

    return state
  end

  def vm_count_on
    return get_assoc(:vms, :on).length
  end

  def vm_count_off
    return get_assoc(:vms, :off).length
  end

  def host_count_on
    return get_assoc(:hosts, :on).length
  end

  def host_count_off
    return get_assoc(:hosts, :off).length
  end

  def storages
    ids = get_assoc(:storages, :on)
    return ids.empty? ? [] : Storage.find_all_by_id(ids, :order => :id)
  end

  def ext_management_systems
    ids = get_assoc(:ext_management_systems, :on)
    return ids.empty? ? [] : ExtManagementSystem.find_all_by_id(ids, :order => :id)
  end

  def ems_clusters
    ids = get_assoc(:ems_clusters, :on)
    return ids.empty? ? [] : EmsCluster.find_all_by_id(ids, :order => :id)
  end

  def hosts
    ids = get_assoc(:hosts)
    return ids.empty? ? [] : Host.find_all_by_id(ids, :order => :id)
  end

  def vms
    ids = get_assoc(:vms)
    return ids.empty? ? [] : VmOrTemplate.find_all_by_id(ids, :order => :id)
  end

  def get_assoc(relat, mode = nil)
    assoc = state_data.fetch_path(:assoc_ids, relat.to_sym)
    return [] if assoc.nil?

    ids = mode.nil? ? (assoc[:on] || []) + (assoc[:off] || []) : assoc[mode.to_sym]
    return ids.nil? ? [] : ids.uniq.sort
  end

  def self.capture_total(obj, field)
    return obj.send("aggregate_#{field}") if obj.respond_to?("aggregate_#{field}")
    return nil unless obj.respond_to?(:hardware) && obj.hardware
    return field == :memory ? obj.hardware.memory_cpu : obj.hardware.aggregate_cpu_speed
  end

  def self.capture_assoc_ids(obj)
    result = {}
    ASSOCIATIONS.each do |assoc|
      method = assoc
      method = (obj.kind_of?(EmsCluster) ? :all_vms_and_templates : :vms_and_templates) if assoc == :vms
      next unless obj.respond_to?(method)
      assoc_recs = obj.send(method)
      has_state = assoc_recs[0] && assoc_recs[0].respond_to?(:state)

      r = result[assoc] = {:on => [], :off => []}
      r_on = r[:on]
      r_off = r[:off]
      assoc_recs.each do |o|
        state = has_state ? o.state : 'on'
        case state
        when 'on' then r_on << o.id
        else r_off << o.id
        end
      end

      r_on.uniq!
      r_on.sort!
      r_off.uniq!
      r_off.sort!
    end
    return result.blank? ? nil : result
  end

  def self.capture_parent_cluster(obj)
    return unless obj.is_a?(Host) || obj.is_a?(VmOrTemplate)
    c = obj.parent_cluster
    return c ? c.id : nil
  end

  def self.capture_parent_host(obj)
    return unless obj.is_a?(VmOrTemplate)
    return obj.host_id
  end

  def self.capture_parent_storage(obj)
    return unless obj.is_a?(VmOrTemplate)
    return obj.storage_id
  end

  def self.capture_parent_ems(obj)
    return unless obj.respond_to?(:ems_id)
    return obj.ems_id
  end

  def self.capture_reserve(obj, field)
    return unless obj.respond_to?(field)
    return obj.send(field)
  end

  def self.capture_tag_names(obj)
    obj.tag_list(:ns => "/managed").split.join("|")
  end

  def self.capture_vm_disk_storage(obj, field)
    return unless obj.is_a?(VmOrTemplate)
    return obj.send("#{field}_storage")
  end

  def self.capture_numvcpus(obj)
    return nil unless obj.kind_of?(VmOrTemplate) && obj.respond_to?(:hardware) && obj.hardware
    # FIXME: this is a z-stream patch
    # this method name should really be changed to #capture_logical_cpus to
    # match the actual column being read, however, there are several reports
    # depending on the name :numvcpus
    # A larger patch should be done outside of a z-stream release
    return obj.hardware.logical_cpus
  end
end
