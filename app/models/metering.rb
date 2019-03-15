module Metering
  extend ActiveSupport::Concern
  DISALLOWED_SUFFIXES = %w(_cost chargeback_rates).freeze
  METERING_ALLOCATED_FIELDS = %w(metering_allocated_cpu_cores_metric metering_allocated_cpu_metric metering_allocated_memory_metric).freeze
  ALLOWED_FIELD_SUFFIXES = %w[
    -beginning_of_resource_existence_in_report_interval
    -end_of_resource_existence_in_report_interval
  ].freeze

  included do
    def self.attribute_names
      super.reject { |x| x.ends_with?(*DISALLOWED_SUFFIXES) }
    end
  end

  def calculate_costs(consumption, _)
    self.fixed_compute_metric = consumption.chargeback_fields_present if consumption.chargeback_fields_present
    self.metering_used_metric = consumption.metering_used_fields_present if consumption.metering_used_fields_present
    self.existence_hours_metric = consumption.consumed_hours_in_interval

    case self
    when MeteringVm
      self.metering_allocated_cpu_metric = consumption.metering_allocated_for(:derived_vm_numvcpus)
      self.metering_allocated_memory_metric = consumption.metering_allocated_for(:derived_memory_available)
    when MeteringContainerProject
      self.metering_allocated_cpu_cores_metric = consumption.metering_allocated_for(:cpu_usage_rate_average)
      self.metering_allocated_memory_metric = consumption.metering_allocated_for(:derived_memory_available)
    when MeteringContainerImage
      cpu_allocation = consumption.current_value(:derived_vm_numvcpu_cores.to_s, nil)
      count_cpu_allocation = cpu_allocation.present? && cpu_allocation.nonzero?
      self.metering_allocated_cpu_cores_metric = count_cpu_allocation ? existence_hours_metric : 0
      memory_allocation = consumption.current_value(:derived_memory_available.to_s, nil)
      count_memory_allocation = memory_allocation.present? && memory_allocation.nonzero?
      self.metering_allocated_memory_metric = count_memory_allocation ? existence_hours_metric : 0
    end

    self.beginning_of_resource_existence_in_report_interval = consumption.consumption_start
    self.end_of_resource_existence_in_report_interval = consumption.consumption_end

    relevant_fields.each do |field|
      next unless self.class.report_col_options.include?(field)
      group, source, * = field.split('_')

      if field == 'net_io_used_metric'
        group = 'net_io'
        source = 'used'
      end

      if field == 'disk_io_used_metric'
        group = 'disk_io'
        source = 'used'
      end

      if field == 'cpu_cores_used_metric'
        group = 'cpu_cores'
        source = 'used'
      end

      if field == 'cpu_cores_allocated_metric'
        group = 'cpu_cores'
        source = 'allocated'
      end

      chargable_field = ChargeableField.find_by(:group => group, :source => source)
      next if METERING_ALLOCATED_FIELDS.include?(field) || field == "existence_hours_metric" || field == "fixed_compute_metric" || chargable_field&.metering?
      value = chargable_field.measure_metering(consumption, @options) if chargable_field
      self[field] = (value || 0)
    end
  end
end
