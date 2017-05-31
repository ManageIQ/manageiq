module TaskHelpers
  class Exports
    class Policies
      def export(options = {})
        export_dir = options[:directory]

        policies = if options[:all]
                     MiqPolicy.order(:id).all
                   else
                     MiqPolicy.order(:id).where(:read_only => [false, nil])
                   end

        policies.each do |p|
          fname = Exports.safe_filename(p.description, options[:keep_spaces])
          File.write("#{export_dir}/#{fname}.yaml", p.export_to_yaml)
        end
      end
    end
  end
end
