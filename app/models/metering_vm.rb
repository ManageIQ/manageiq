class MeteringVm < ChargebackVm
  set_columns_hash(
    :metering_allocated_cpu_metric                      => :integer,
    :metering_allocated_memory_metric                   => :integer,
    :metering_used_metric                               => :integer,
    :existence_hours_metric                             => :integer,
    :beginning_of_resource_existence_in_report_interval => :datetime,
    :end_of_resource_existence_in_report_interval       => :datetime
  )

  include Metering

  def self.report_col_options
    {
      "cpu_allocated_metric"             => {:grouping => [:total]},
      "cpu_used_metric"                  => {:grouping => [:total]},
      "disk_io_used_metric"              => {:grouping => [:total]},
      "existence_hours_metric"           => {:grouping => [:total]},
      "fixed_compute_metric"             => {:grouping => [:total]},
      "memory_allocated_metric"          => {:grouping => [:total]},
      "metering_allocated_cpu_metric"    => {:grouping => [:total]},
      "metering_allocated_memory_metric" => {:grouping => [:total]},
      "memory_used_metric"               => {:grouping => [:total]},
      "metering_used_metric"             => {:grouping => [:total]},
      "net_io_used_metric"               => {:grouping => [:total]},
      "storage_allocated_metric"         => {:grouping => [:total]},
      "storage_used_metric"              => {:grouping => [:total]},
    }
  end

  def self.build_results_for_report_MeteringVm(options)
    build_results_for_report_ChargebackVm(options)
  end

  def self.display_name(number = 1)
    n_('Metering for VM', 'Metering for VMs', number)
  end
end
