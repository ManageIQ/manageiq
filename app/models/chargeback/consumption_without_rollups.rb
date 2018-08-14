class Chargeback
  class ConsumptionWithoutRollups < Consumption
    delegate :id, :name, :type, :to => :resource, :prefix => :resource
    attr_reader :resource

    def initialize(resource, start_time, end_time)
      super(start_time, end_time)
      @resource = resource
    end

    def timestamp
      @start_time
    end

    def parent_ems
      resource.ext_management_system
    end

    def tag_names
      resource.tags.collect(&:name)
    end

    def hash_features_affecting_rate
      resource.id
    end

    def tag_list_with_prefix
      tag_names.map { |t| "vm/tag#{t}" }
    end

    def parents_determining_rate
      [resource.host, resource.ems_cluster, resource.storage, resource.try(:cloud_volumes), parent_ems, resource.tenant,
       MiqEnterprise.my_enterprise].flatten.compact
    end

    def none?(metric, sub_metric = nil)
      current_value(metric, sub_metric).nil?
    end

    def chargeback_fields_present
      1 # Yes, charge this interval as fixed_compute_*_*
    end

    def metering_used_fields_present
      0 # we don't count used hours in metering report
    end

    def current_value(metric, sub_metric = nil)
      # Return the last seen allocation for charging purposes.
      @value ||= {}
      metric_key = "#{metric}#{sub_metric}"
      @value[metric_key] ||= case metric
                             when 'derived_vm_numvcpus' # Allocated CPU count
                               resource.hardware.try(:cpu_total_cores)
                             when 'derived_memory_available'
                               resource.hardware.try(:memory_mb)
                             when 'derived_vm_allocated_disk_storage'
                               if sub_metric.present?
                                 resource.cloud_volumes.where(:volume_type => sub_metric).sum(:size) || 0
                               else
                                 resource.allocated_disk_storage
                               end
                             end
    end
    alias avg current_value
    alias max current_value
    alias sum current_value
    alias sum_of_maxes_from_grouped_values current_value
    private :current_value
  end
end
