module TaskHelpers
  class Exports
    class Policies
      def export(options = {})
        export_dir = options[:directory]

        policies = options[:all] ? MiqPolicy.all : MiqPolicy.where(:read_only => [false, nil])

        policies.order(:id).each do |policy|
          $log.info("Exporting Policy: #{policy.description} (ID: #{policy.id})")

          filename = Exports.safe_filename(policy.description, options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", policy.export_to_yaml)
        end
      end
    end
  end
end
