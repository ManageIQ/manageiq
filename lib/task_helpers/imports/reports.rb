module TaskHelpers
  class Imports
    class Reports
      def import(options = {})
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Reports from: #{filename}")

          report_options = { :userid    => 'admin',
                             :overwrite => options[:overwrite],
                             :save      => true }

          File.open(filename, 'r') do |report_fd|
            MiqReport.import(report_fd, report_options)
          rescue ActiveModel::UnknownAttributeError, RuntimeError => err
            $log.error("Error importing #{filename} : #{err.message}")
            warn("Error importing #{filename} : #{err.message}")
          end
        end
      end
    end
  end
end
