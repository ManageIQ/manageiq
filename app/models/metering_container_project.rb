class MeteringContainerProject < ChargebackContainerProject
  def self.report_col_options
    {
      "cpu_cores_used_metric" => {:grouping => [:total]},
      "fixed_compute_metric"  => {:grouping => [:total]},
      "memory_used_metric"    => {:grouping => [:total]},
      "metering_used_metric"  => {:grouping => [:total]},
      "net_io_used_metric"    => {:grouping => [:total]},
    }
  end

  def self.build_results_for_report_MeteringContainerProject(options)
    build_results_for_report_ChargebackContainerProject(options)
  end
end
