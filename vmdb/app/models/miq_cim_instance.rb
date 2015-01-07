require 'miq_storage_defs'

# Required for loading serialized objects in 'obj' column
add_to_load_path Rails.root.join("..", "lib", "wbem")
require 'wbem'
require 'NetappManageabilityAPI/NmaTypes'

class MiqCimInstance < ActiveRecord::Base

  has_many  :miq_cim_associations,
        :dependent    => :destroy

  has_many  :associations_we_are_result_of,
        :class_name   => "MiqCimAssociation",
        :foreign_key  => "result_instance_id",
        :dependent    => :destroy

  has_many  :elements_with_metrics,
        :class_name   => "MiqCimInstance",
        :foreign_key  => "metric_top_id"

  belongs_to  :metrics,
        :class_name   => "MiqStorageMetric",
        :foreign_key  => "metric_id",
        :dependent    => :destroy

  belongs_to  :agent,
        :class_name   => "StorageManager",
        :foreign_key  => "agent_id"

  belongs_to  :top_managed_element,
        :class_name   => "MiqCimInstance",
        :foreign_key  => "top_managed_element_id"

  belongs_to  :vmdb_obj,
        :polymorphic  => true

  belongs_to  :zone

  serialize :obj
  serialize :obj_name
  serialize :type_spec_obj

  virtual_column  :evm_display_name,      :type => :string
  virtual_column  :last_update_status_str,  :type => :string

  include MiqStorageDefs

  #
  # The order of the entries in the following array is significant;
  # relevant subclasses must appear before their superclasses.
  #
  SUPER_CLASSES = [
    'CIM_StorageExtent',
    'CIM_CompositeExtent',
    'CIM_LogicalDisk',
    'CIM_StorageVolume',
    'CIM_ComputerSystem',
    'SNIA_FileShare',
    'SNIA_LocalFileSystem',
    'MIQ_CimVirtualDisk',
    'MIQ_CimVirtualMachine',
    'MIQ_CimDatastore',
    'MIQ_CimHostSystem'
  ]

  def self.topManagedElements
    self.where(:is_top_managed_element => true).to_a
  end

  def self.find_kinda(cimClass, zoneId)
    self.where("class_hier LIKE ? AND zone_id = ?", "%/#{cimClass}/%", zoneId).to_a
  end

  def evm_display_name
    return property('ElementName') || property('Name') || property('DeviceID')
  end

  def last_update_status_str
    return "OK"         if last_update_status == STORAGE_UPDATE_OK
    #
    # If any agent in this zone is STORAGE_UPDATE_IN_PROGRESS or STORAGE_UPDATE_PENDING, then "In Progress"
    # should be returned, because the true status of the instance can only be determined when the full
    # scan is complete.
    #
    aa = MiqSmisAgent.find(:all, :conditions => [
      "zone_id = ? and (last_update_status = ? or last_update_status = ?)",
      zone_id, STORAGE_UPDATE_IN_PROGRESS, STORAGE_UPDATE_PENDING
    ])
    return "In Progress"    unless aa.empty?
    return "Agent Inaccessible" if last_update_status == STORAGE_UPDATE_AGENT_INACCESSIBLE

    if last_update_status == STORAGE_UPDATE_NO_AGENT
      return "No Agent"   unless agent
      return "Failed"     if agent.last_update_status == STORAGE_UPDATE_FAILED
    elsif last_update_status == STORAGE_UPDATE_AGENT_OK_NO_INSTANCE
      return "Failed"     if agent.last_update_status == STORAGE_UPDATE_FAILED
      return "No Instance"
    end
    return "Unknown"
  end

  #
  # Are metrics for the given interval available?
  # interval_name: "hourly" || "daily" || "realtime"
  #
  def has_perf_data?(interval_name = "hourly")
    @has_perf_data ||= {}
    unless (rv = @has_perf_data[interval_name]).nil?
      return rv
    end

    return @has_perf_data[interval_name] = false if self.metrics.nil?

    if interval_name == "realtime"
      return @has_perf_data[interval_name] = self.metrics.miq_derived_metrics.exists?
    end
    return @has_perf_data[interval_name] = self.metrics.miq_metrics_rollups.exists?(:rollup_type => interval_name)
  end

  def last_capture(interval_name = "hourly")
    return nil unless has_metrics?
    if interval_name == "realtime"
      perf = self.metrics.miq_derived_metrics.first(
        :select     => "statistic_time",
        :order      => "statistic_time DESC"
      )
    else
      perf = self.metrics.miq_metrics_rollups.first(
        :select     => "statistic_time",
        :conditions => {:rollup_type => interval_name},
        :order      => "statistic_time DESC"
      )
    end
    return perf.nil? ? nil : perf.statistic_time
  end

  def first_capture(interval_name = "hourly")
    return nil unless has_metrics?
    if interval_name == "realtime"
      perf = self.metrics.miq_derived_metrics.first(
        :select     => "statistic_time",
        :order      => "statistic_time ASC"
      )
    else
      perf = self.metrics.miq_metrics_rollups.first(
        :select     => "statistic_time",
        :conditions => {:rollup_type => interval_name},
        :order      => "statistic_time ASC"
      )
    end
    return perf.nil? ? nil : perf.statistic_time
  end

  def first_and_last_capture(interval_name = "hourly")
    return [first_capture(interval_name), last_capture(interval_name)].compact
  end

  #
  # Does this object support metrics collection.
  #
  def has_metrics?
    !metrics.nil?
  end

  def derived_metrics
    return [] unless has_metrics?
    metrics.miq_derived_metrics
  end

  def derived_metrics_in_range(start_time, end_time)
    return [] unless has_metrics?
    metrics.derived_metrics_in_range(start_time, end_time)
  end

  # XXX
  def latest_derived_metrics
    derived_metrics.last
  end

  # XXX
  def earliest_derived_metrics
    derived_metrics.first
  end

  def metrics_rollups
    return [] unless has_metrics?
    metrics.miq_metrics_rollups
  end

  def metrics_rollups_in_range(rollupType, startTime, endTime)
    return [] unless has_metrics?
    metrics.metrics_rollups_in_range(rollupType, startTime, endTime)
  end

  def metrics_rollups_by_rollup_type(rollupType)
    return [] unless has_metrics?
    metrics.metrics_rollups_by_rollup_type(rollupType)
  end

  def vendor
    return "NetApp" if class_name =~ /^ONTAP_/
    return "Unknown"
  end

  def class_hier
    chs = read_attribute(:class_hier)
    chs = chs[1..-2] if chs
    return chs.split('/') if chs
    return []
  end

  def class_hier=(val)
    if val.kind_of?(Array)
      val = '/' + val.join('/') + '/'
    end
    write_attribute(:class_hier, val)
  end

  def addAssociation(result_instance, assoc)
    MiqCimAssociation.add_association(assoc, self, result_instance)
  end

  #
  # Get the nodes associated with this node through the given association.
  #
  def getAssociators(association)
    results = []
    query = miq_cim_associations.scoped.includes(:result_instance).select(:result_instance_id)
    query = query.where_association(association)
    query.find_each { |a| results << a.result_instance }
    return results.uniq
  end

  def getAssociatedVmdbObjs(association)
    results = []
    query = miq_cim_associations.scoped.includes(:result_instance => :vmdb_obj).select(:result_instance_id)
    query = query.where_association(association)
    query.find_each { |a| results << a.result_instance.vmdb_obj }
    return results.uniq
  end

  #
  # Get the associations from this node that match the given association.
  #
  def getAssociations(association)
    return miq_cim_associations.scoped.where_association(association).all
  end

  #
  # Return the number of associations from this node that match the given association.
  #
  def getAssociationSize(association)
    return miq_cim_associations.scoped.where_association(association).size
  end

  def mark_associations_stale
    self.miq_cim_associations.update_all(:status => MiqCimAssociation::STATUS_STALE)
  end

  def addNewMetric(metric)
    metric.miq_cim_instance = self
    self.metrics = metric
    metric.save
  end

  def updateStats(metricObj)
    self.metrics.metric_obj = metricObj
    self.metrics.save
  end

  def kinda?(className)
    class_hier.include? className
  end

  def typeFromClassHier
    class_hier.each { |c| return typeFromClassName(c) if SUPER_CLASSES.include?(c) }
    return nil
  end

  def typeFromClassName(className)
    return className.underscore.camelize
  end

  def operational_status_to_str(val)
    return "Not Available" if val.nil?
    case val[0]
    when 2
      return "OK"
    when 3
      return "Degraded"
    when 6
      return "Error"
    when 8
      return "Starting"
    when 9
      return "Stopping"
    when 10
      return "Stopped"
    when 12
      return "No contact"
    when 13
      return "Lost communication"
    when 15
      return "Dormant"
    else
      return "Unknown (#{val[0]})"
    end
  end

  def health_state_to_str(val)
    return "Not Available"    if val.nil?
    return "OK"         if val == 5
    return "Issue Detected"   if val > 5 && val <= 10
    return "Attention Required" if val > 10 && val < 30
    return "Major Failure"    if val >= 30
    return "Unknown (#{val})"
  end

  def getLeafNodes(prof, node, retHash, level=0, visited={})
    objName = node.obj_name_str

    return if visited[objName]

    unless prof
      if !retHash.has_key?(objName)
        retHash[objName] = node
      end
      visited[objName] = true
      return
    end

    prof = [ prof ] unless prof.kind_of?(Array)

    children = false

    prof.each do |p|
      associations = p[:association]
      associations = [ associations ] unless associations.kind_of?(Array)

      associations.each do |a|
        node.getAssociators(a).each do |an|
          children = true
          if p[:flags][:recurse]
            getLeafNodes(p, an, retHash, level + 1, visited)
          end
          getLeafNodes(p[:next], an, retHash, level + 1, visited)
        end
      end
    end
    visited[objName] = true

    if children
      retHash.delete(objName) if retHash.has_key?(objName)
    elsif !retHash.has_key?(objName)
      retHash[objName] = node
    end
  end

  def property(key)
    v = obj.properties[key]
    return nil if v.nil?
    if v.value.kind_of?(Array)
      v.value.collect { |val| decode(val) }
    else
      decode(v.value)
    end
  end

  def dumpInstance(globalIndent="", level=0, io=$stdout)
    obj.properties.each do |k, v|
      unless v.value.kind_of?(Array)
        indentedPrint("  #{k} => #{v.value} (#{v.value.class})", globalIndent, level, io)
      else
        indentedPrint("  #{k} =>", globalIndent, level, io)
        v.value.each { |val| indentedPrint("          #{val}", globalIndent, level, io) }
      end
    end
  end

  def indentedPrint(s, globalIndent, i, io=$stdout)
        io.print globalIndent + "  " * i
        io.puts s
  end

  private

  def decode(val)
    return val.value if val.kind_of?(WBEM::Uint8)
    return val.value if val.kind_of?(WBEM::Uint16)
    return val.value if val.kind_of?(WBEM::Uint32)
    return val.value if val.kind_of?(WBEM::Uint64)
    return val.value if val.kind_of?(WBEM::Boolean)
    return val
  end

end
