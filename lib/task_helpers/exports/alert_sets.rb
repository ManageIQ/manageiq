module TaskHelpers
  class Exports
    class AlertSets
      def export(options = {})
        export_dir = options[:directory]

        MiqAlertSet.order(:id).all.each do |a|
          # Replace characters in the description that are not allowed in filenames
          fname = Exports.safe_filename(a.description, options[:keep_spaces])
          File.write("#{export_dir}/#{fname}.yaml", a.export_to_yaml)
        end
      end
    end
  end
end
