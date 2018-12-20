module TaskHelpers
  class Exports
    class Reports
      def export(options = {})
        export_dir = options[:directory]

        custom_reports = options[:all] ? MiqReport.all : MiqReport.where(:rpt_type => "Custom")

        custom_reports.each do |report|
          filename = Exports.safe_filename(report.name, options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", report.export_to_array.to_yaml)
        end
      end
    end
  end
end
