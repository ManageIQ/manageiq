class VimPerformanceState < ApplicationRecord
  include_concern 'Purging'

  serialize :state_data

  belongs_to :resource, :polymorphic => true

  ASSOCIATIONS = [:vms, :hosts, :ems_clusters, :ext_management_systems, :storages, :container_nodes, :container_groups,
                  :all_container_groups]

  # Define accessors for state_data information
  [
    :assoc_ids,
    :host_sockets,
    :parent_host_id,
    :parent_storage_id,
    :parent_ems_id,
    :parent_ems_cluster_id,
    :tag_names,
    :image_tag_names,
    :numvcpus,
    :total_cpu,
    :total_mem,
    :reserve_cpu,
    :reserve_mem,
    :vm_allocated_disk_storage,
    :allocated_disk_types,
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
  # => vm_count_total   (derive from assoc_ids)
  # => host_count_on    (derive from assoc_ids)
  # => host_count_off   (derive from assoc_ids)
  # => host_count_total (derive from assoc_ids)
  # => host_sockets     (derive from assoc_ids)

  def self.capture(obj)
    ts = Time.now.utc
    ts = Time.utc(ts.year, ts.month, ts.day, ts.hour)
    state = obj.vim_performance_states.find_by(:timestamp => ts)
    return state unless state.nil?

    state = obj.vim_performance_states.build(:timestamp => ts)
    state.capture
    state.save

    state
  end

  def capture
    self.state_data ||= {}
    self.capture_interval = 3600
    capture_assoc_ids
    capture_parent_host
    capture_parent_storage
    capture_parent_ems
    capture_parent_cluster
    capture_cpu_total_cores
    capture_totals
    capture_reserve
    capture_vm_disk_storage
    capture_disk_types
    capture_tag_names
    capture_image_tag_names
    capture_host_sockets
  end

  def vm_count_on
    get_assoc(:vms, :on).length
  end

  def vm_count_off
    get_assoc(:vms, :off).length
  end

  def vm_count_total
    get_assoc(:vms).length
  end

  def host_count_on
    get_assoc(:hosts, :on).length
  end

  def host_count_off
    get_assoc(:hosts, :off).length
  end

  def host_count_total
    get_assoc(:hosts).length
  end

  def storages
    ids = get_assoc(:storages, :on)
    ids.empty? ? [] : Storage.where(:id => ids).order(:id).to_a
  end

  def ext_management_systems
    ids = get_assoc(:ext_management_systems, :on)
    ids.empty? ? [] : ExtManagementSystem.where(:id => ids).order(:id).to_a
  end

  def ems_clusters
    ids = get_assoc(:ems_clusters, :on)
    ids.empty? ? [] : EmsCluster.where(:id => ids).order(:id).to_a
  end

  def hosts
    ids = get_assoc(:hosts)
    ids.empty? ? [] : Host.where(:id => ids).order(:id).to_a
  end

  def vms
    ids = get_assoc(:vms)
    ids.empty? ? [] : VmOrTemplate.where(:id => ids).order(:id).to_a
  end

  def container_nodes
    ids = get_assoc(:container_nodes)
    ids.empty? ? [] : ContainerNode.where(:id => ids).order(:id).to_a
  end

  def container_groups
    ids = get_assoc(:container_groups)
    ids.empty? ? [] : ContainerGroup.where(:id => ids).order(:id).to_a
  end

  def all_container_groups
    ids = get_assoc(:all_container_groups)
    ids.empty? ? [] : ContainerGroup.where(:id => ids).order(:id).to_a
  end

  def get_assoc(relat, mode = nil)
    assoc = state_data.fetch_path(:assoc_ids, relat.to_sym)
    return [] if assoc.nil?

    ids = mode.nil? ? (assoc[:on] || []) + (assoc[:off] || []) : assoc[mode.to_sym]
    ids.nil? ? [] : ids.uniq.sort
  end

  private

  def capture_disk_types
    if hardware
      self.allocated_disk_types = hardware.disks.each_with_object({}) do |disk, res|
        next if disk.size.nil?
        type = disk.backing.try(:volume_type) || 'unclassified'
        res[type] = (res[type] || 0) + disk.size
      end
    end
  end

  def capture_totals
    self.total_cpu = capture_total(:cpu_speed)
    self.total_mem = capture_total(:memory)
  end

  def capture_total(field)
    return resource.send("aggregate_#{field}") if resource.respond_to?("aggregate_#{field}")

    field == :memory ? hardware.try(:memory_mb) : hardware.try(:aggregate_cpu_speed)
  end

  def capture_assoc_ids
    result = {}
    ASSOCIATIONS.each do |assoc|
      method = if assoc == :vms
                 if resource.kind_of?(EmsCluster)
                   :all_vms_and_templates
                 elsif resource.kind_of?(Service)
                   :vms
                 else
                   :vms_and_templates
                 end
               else
                 assoc
               end
      next unless resource.respond_to?(method)
      assoc_recs = resource.send(method)
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
    self.assoc_ids = result.presence
  end

  def capture_parent_cluster
    if resource.kind_of?(Host) || resource.kind_of?(VmOrTemplate)
      self.parent_ems_cluster_id = resource.parent_cluster.try(:id)
    end
  end

  def capture_parent_host
    self.parent_host_id = resource.host_id if resource.kind_of?(VmOrTemplate)
  end

  def capture_parent_storage
    self.parent_storage_id = resource.storage_id if resource.kind_of?(VmOrTemplate)
  end

  def capture_parent_ems
    self.parent_ems_id = resource.try(:ems_id)
  end

  def capture_reserve
    self.reserve_cpu = resource.try(:cpu_reserve)
    self.reserve_mem = resource.try(:memory_reserve)
  end

  def capture_tag_names
    self.tag_names = resource.perf_tags
  end

  def capture_image_tag_names
    self.image_tag_names = if resource.respond_to?(:container_image) && resource.container_image.present?
                             resource.container_image.perf_tags
                           else
                             ''
                           end
  end

  def capture_vm_disk_storage
    if resource.kind_of?(VmOrTemplate)
      [:used_disk, :allocated_disk].each do |type|
        send("vm_#{type}_storage=", resource.send("#{type}_storage"))
      end
    end
  end

  def capture_cpu_total_cores
    # TODO: This is cpu_total_cores and needs to be renamed, but reports depend on the name :numvcpus
    self.numvcpus = hardware.try(:cpu_total_cores)
  end

  def capture_host_sockets
    self.host_sockets = if resource.kind_of?(Host)
                          resource.hardware.try(:cpu_sockets)
                        elsif resource.respond_to?(:hosts)
                          resource.hosts.includes(:hardware).collect { |h| h.hardware.try(:cpu_sockets) }.compact.sum
                        end
  end

  def hardware
    if resource.respond_to?(:hardware)
      resource.hardware
    elsif resource.respond_to?(:container_node)
      resource.container_node.try(:hardware)
    end
  end
end
