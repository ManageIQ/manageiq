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

    def none?(_metric)
      true # No, values except for fixed (RateDetail.fixed?)
    end

    def max(_metric)
      raise NotImplementedError # Unreachable code since none?==true
    end

    def avg(_metric)
      raise NotImplementedError # Unreachable code since none?==true
    end

    def chargeback_fields_present
      1 # Yes, charge this interval as fixed_compute_*_*
    end
  end
end
