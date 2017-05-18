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
      [resource.host, resource.ems_cluster, resource.storage, parent_ems, resource.tenant,
       MiqEnterprise.my_enterprise].compact
    end

    def none?(metric)
      current_value(metric).nil?
    end

    def chargeback_fields_present
      1 # Yes, charge this interval as fixed_compute_*_*
    end

    def current_value(metric)
      # Return the last seen allocation for charging purposes.
      @value ||= {}
      @value[metric] ||= case metric
                         when 'derived_vm_numvcpus' # Allocated CPU count
                           resource.hardware.try(:cpu_total_cores)
                         when 'derived_memory_available'
                           resource.hardware.try(:memory_mb)
                         when 'derived_vm_allocated_disk_storage'
                           resource.allocated_disk_storage
                         end
      @value[metric]
    end
    alias avg current_value
    alias max current_value
    private :current_value
  end
end
