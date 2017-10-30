class MeteringVm < ChargebackVm
  include Metering

  def self.report_col_options
    {
      "cpu_allocated_metric"     => {:grouping => [:total]},
      "cpu_used_metric"          => {:grouping => [:total]},
      "disk_io_used_metric"      => {:grouping => [:total]},
      "fixed_compute_metric"     => {:grouping => [:total]},
      "memory_allocated_metric"  => {:grouping => [:total]},
      "memory_used_metric"       => {:grouping => [:total]},
      "metering_used_metric"     => {:grouping => [:total]},
      "net_io_used_metric"       => {:grouping => [:total]},
      "storage_allocated_metric" => {:grouping => [:total]},
      "storage_used_metric"      => {:grouping => [:total]},
    }
  end

  def self.build_results_for_report_MeteringVm(options)
    build_results_for_report_ChargebackVm(options)
  end
end
