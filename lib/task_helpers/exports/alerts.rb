module TaskHelpers
  class Exports
    class Alerts
      def export(options = {})
        export_dir = options[:directory]

        MiqAlert.order(:id).all.each do |a|
          fname = Exports.safe_filename(a.description, options[:keep_spaces])
          File.write("#{export_dir}/#{fname}.yaml", a.export_to_yaml)
        end
      end
    end
  end
end
